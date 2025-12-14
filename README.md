# Documentație Tehnică - Generator Semnal PWM
### Echipa: Neamu Ciprian, Voiculescu Nicolae, Babencu Cristian
### Grupa: 333AA

## Mentiuni:

`top.v` a fost  modificat deoarece acesta nu era complet.

## 1. Introducere

Această documentație descrie implementarea unui periferic hardware pentru generarea semnalelor PWM (Pulse Width Modulation) în limbajul Verilog. Perifericul este conceput să funcționeze ca un modul slave într-un sistem mai complex, comunicând prin protocolul SPI și oferind control flexibil asupra caracteristicilor semnalului PWM generat.

### 1.1 Structura Modulară

Perifericul este împărțit în 5 module principale, fiecare cu responsabilități distincte:
- **spi_bridge**: Gestionează comunicația SPI cu masterul extern
- **instr_dcd**: Decodifică instrucțiunile primite și coordonează accesul la registre
- **regs**: Stochează configurația perifericului în registre hardware
- **counter**: Implementează numărătorul configurable care furnizează baza de timp
- **pwm_gen**: Generează semnalul PWM efectiv pe baza configurației și valorii counter-ului

## 2. Modulul SPI Bridge (`spi_bridge.v`)

### 2.1 Scopul Modulului

Bridge-ul SPI asigură interfața de comunicație între masterul extern și logica internă a perifericului. Acesta operează în domeniul de ceas SPI (SCLK) și transferă date byte cu byte către/de la modulele interne.

### 2.2 Detalii de Implementare

#### 2.2.1 Protocoalele SPI Utilizate
Implementarea respectă configurația SPI standard cu:
- **CPOL = 0, CPHA = 0**: Datele sunt plasate pe frontul descrescător și citite pe frontul crescător al SCLK
- **MSB first**: Primul bit transmis este cel mai semnificativ
- **Chip Select activ low**: Comunicarea este activă când `cs_n = 0`

#### 2.2.2 Logica de Recepție (MOSI)

```verilog
byte_buffer <= byte_buffer << 1;
byte_buffer[0] <= mosi;
```

Implementarea folosește un registru de deplasare (shift register) pentru a asambla biții primiți secvențial în bytes completi. La fiecare front crescător de SCLK:
1. Conținutul buffer-ului este deplasat la stânga cu o poziție
2. Noul bit de pe linia MOSI este plasat în poziția LSB
3. După 8 cicluri, în buffer se găsește un byte complet, semnalizat prin `byte_sync = 1`

#### 2.2.3 Detectarea Primului Byte

Primul byte primit are o semnificație specială (conține opcode-ul operației), astfel că bridge-ul trebuie să-l detecteze:

```verilog
if (bits_read == 1) begin
    is_write <= byte_buffer[0];
    is_read <= ~byte_buffer[0];
end
```

La bitul 1 (al doilea bit citit), modulul examinează bitul 7 al primului byte (care se află în `byte_buffer[0]` datorită shift-ului) pentru a determina dacă operația este de scriere (1) sau citire (0).

Flag-ul `was_first_byte_read` se activează după completarea primului byte și determină comportamentul ulterior al bridge-ului.

#### 2.2.4 Logica de Transmisie (MISO)

```verilog
assign miso = (was_first_byte_read && is_write) ? data_out[7 - bits_written] : 1'b0;
```

Pentru operațiile de citire, după ce primul byte a fost procesat, bridge-ul transmite pe MISO byte-ul de date primit de la modulul `instr_dcd` prin semnalul `data_out`. Biții sunt trimiși în ordine, indexați prin counter-ul `bits_written`.

### 2.3 Sincronizarea Domeniilor de Ceas

Deși cerința specifică că SCLK și CLK sunt ambele la 10MHz și sincrone, implementarea actuală operează exclusiv în domeniul SCLK pentru logica SPI. Semnalul `byte_sync` servește drept punct de sincronizare între cele două domenii, fiind utilizat de modulul `instr_dcd` care operează în domeniul CLK.

## 3. Modulul Decodor de Instrucțiuni (`instr_dcd.v`)

### 3.1 Scopul Modulului

Decodorul de instrucțiuni acționează ca un FSM (Finite State Machine) care interpretează secvențele de bytes primite de la SPI și generează semnalele de control corespunzătoare pentru accesul la registre.

### 3.2 Stările FSM

Modulul utilizează un registru de stare pe 3 biți (`internal_state`) care codifică atât starea curentă cât și informații despre operația în curs:

```
Bit 2: 0 = Necesită primul byte | 1 = Primul byte procesat
Bit 1: 0 = Operație READ | 1 = Operație WRITE
Bit 0: 0 = Zona LOW [7:0] | 1 = Zona HIGH [15:8]
```

Stările definite ca parametri:
- `NEEDS_FIRST_BYTE (3'b000)`: Starea inițială, în așteptarea primului byte
- `READY_READ_LO (3'b100)`: Pregătit pentru citire din zona LOW
- `READY_READ_HI (3'b101)`: Pregătit pentru citire din zona HIGH
- `READY_WRITE_LO (3'b110)`: Pregătit pentru scriere în zona LOW
- `READY_WRITE_HI (3'b111)`: Pregătit pentru scriere în zona HIGH

### 3.3 Procesarea Setup Byte-ului

Când `byte_sync` devine activ și starea este `NEEDS_FIRST_BYTE`, decodorul extrage informațiile din primul byte:

```verilog
internal_state[2] <= 1'b1;              // Marchează procesarea primului byte
internal_state[1] <= data_in[7];        // R/W bit
internal_state[0] <= data_in[6];        // HIGH/LOW bit
address[5:0] <= data_in[5:0];           // Adresa registrului
```

### 3.4 Procesarea Data Byte-ului

La următorul `byte_sync`, în funcție de starea determinată anterior:
- **Pentru WRITE**: Byte-ul primit este stocat în `internal_buffer` și flag-ul `send_data` devine activ pentru a semnala modulului `regs` că datele sunt valide
- **Pentru READ**: Modulul citește valoarea din `data_read` (furnizată de `regs`) și o plasează în `internal_buffer` pentru transmisie către SPI bridge

### 3.5 Generarea Semnalelor de Control

```verilog
assign write = (internal_state[2]) ? internal_state[1] : read;
assign read = (internal_state[2]) ? ~write : 0;
```

Semnalele `read` și `write` sunt generate combinațional pe baza stării curente. Acestea sunt mutual exclusive și sunt active doar după procesarea primului byte.

## 4. Modulul de Registre (`regs.v`)

### 4.1 Scopul Modulului

Blocul de registre implementează memoria de configurație a perifericului, oferind interfață pentru citire/scriere la adresele definite în specificație și gestionând auto-clear-ul registrului `COUNTER_RESET`.

### 4.2 Harta de Registre

| Registru | Adresă | Tip Acces | Lățime | Descriere |
|----------|--------|-----------|--------|-----------|
| PERIOD | 0x00 | R/W | [15:0] | Perioada numărătorului în cicluri de ceas |
| COUNTER_EN | 0x02 | R/W | 1 bit | Activează/dezactivează numărătorul |
| COMPARE1 | 0x03 | R/W | [15:0] | Prima valoare de comparație pentru PWM |
| COMPARE2 | 0x05 | R/W | [15:0] | A doua valoare de comparație (mod unaligned) |
| COUNTER_RESET | 0x07 | W | 1 bit | Resetează counter-ul (auto-clear după 2 cicluri) |
| COUNTER_VAL | 0x08 | R | [15:0] | Valoarea curentă a counter-ului (read-only) |
| PRESCALE | 0x0A | R/W | [7:0] | Factor de scalare: divizor = 2^prescale |
| UPNOTDOWN | 0x0B | R/W | 1 bit | Direcție numărare: 1=UP, 0=DOWN |
| PWM_EN | 0x0C | R/W | 1 bit | Activează ieșirea PWM |
| FUNCTIONS | 0x0D | R/W | [1:0] | Configurare mod PWM |

### 4.3 Implementarea Accesului la Registre

#### 4.3.1 Operații de Scriere

```verilog
if (write) begin
    case (addr)
        PERIOD_ADDRESS: period_reg[7:0] <= data_write;
        // ... alte registre
    endcase
end
```

La fiecare ciclu de ceas, dacă semnalul `write` este activ, modulul decodifică adresa și scrie valoarea din `data_write` în registrul corespunzător. 

**Observație importantă**: Implementarea actuală scrie doar în partea LOW [7:0] a registrilor pe 16 biți (PERIOD, COMPARE1, COMPARE2). Bitul HIGH/LOW din instruction byte nu este utilizat în implementarea curentă.

#### 4.3.2 Operații de Citire

```verilog
if (read) begin
    case (addr)
        COUNTER_VAL_ADDRESS: buffer_for_reading <= counter_val[7:0];
        // ... alte registre
    endcase
end
```

Pentru citire, valoarea registrului este plasată în `buffer_for_reading`, care este apoi atribuit la `data_read`. Registrul `COUNTER_VAL` este special - el reflectă valoarea dinamică a counter-ului, primită prin input-ul `counter_val`.

### 4.4 Auto-Clear pentru COUNTER_RESET

Cerința specifică că registrul `COUNTER_RESET` trebuie să se șteargă automat după 2 cicluri de ceas de la scriere. Implementarea folosește un counter simplu:

```verilog
if (counter_reset_reg) begin
    if (reset_delay_counter) begin
        counter_reset_reg <= 1'b0;
        reset_delay_counter <= 1'b0;
    end else begin
        reset_delay_counter <= 1'b1;
    end
end
```

**Funcționarea**:
1. **Ciclu 0**: User-ul scrie 1 în `COUNTER_RESET`, `reset_delay_counter` este resetat la 0
2. **Ciclu 1**: `counter_reset_reg = 1`, `reset_delay_counter` devine 1
3. **Ciclu 2**: `counter_reset_reg` se șterge la 0, `reset_delay_counter` revine la 0

Această logică asigură că semnalul de reset este vizibil către modulul `counter` pentru exact 2 cicluri de ceas.

## 5. Modulul Counter (`counter.v`)

### 5.1 Scopul Modulului

Counter-ul furnizează baza de timp pentru generarea semnalului PWM. Acesta poate număra în sus sau în jos, cu o perioadă configurabilă și un prescaler pentru scalarea frecvenței de incrementare.

### 5.2 Prescaler-ul

Prescaler-ul reduce frecvența efectivă de incrementare/decrementare a counter-ului principal:

```verilog
wire [15:0] prescale_cstn = (16'd1 << prescale);
```

Valoarea prescaler-ului este calculată ca 2^prescale, astfel:
- `prescale = 0` → divizor = 1 (incrementare la fiecare ciclu)
- `prescale = 1` → divizor = 2 (incrementare la 2 cicluri)
- `prescale = 2` → divizor = 4
- `prescale = n` → divizor = 2^n

### 5.3 Logica de Numărare

#### 5.3.1 Modul UP (upnotdown = 1)

```verilog
if (cnt == prescale_cstn) begin
    cnt <= 16'd1;
    if (count_val_internal == period) 
        count_val_internal <= 0;
    else 
        count_val_internal <= count_val_internal + 1;
end
else cnt <= cnt + 1;
```

Counter-ul intern `cnt` crește de la 1 la `prescale_cstn`. Când atinge valoarea maximă:
- Se resetează la 1
- Counter-ul principal (`count_val_internal`) se incrementează
- Dacă counter-ul principal atinge `period`, se resetează la 0 (overflow)

#### 5.3.2 Modul DOWN (upnotdown = 0)

```verilog
if (cnt == 1) begin 
    cnt <= prescale_cstn;
    if (count_val_internal == period) 
        count_val_internal <= 0;
    else 
        count_val_internal <= count_val_internal + 1;
end
else cnt <= cnt - 1;
```

În modul DOWN, counter-ul intern `cnt` pornește de la `prescale_cstn` și scade până la 1. **Observație**: Counter-ul principal tot se incrementează (nu decrementează) - doar ritmul de incrementare este controlat de direcția counter-ului intern.

### 5.4 Perioada Efectivă

Counter-ul numără de la 0 la `period` inclusiv, apoi se resetează la 0. Astfel, perioada efectivă este de `period + 1` valori:
- Pentru `period = 7`: counter-ul ia valorile 0, 1, 2, 3, 4, 5, 6, 7, 0, 1, ...
- Perioada în cicluri de ceas = (period + 1) × 2^prescale

### 5.5 Reset Manual

Semnalul `count_reset` resetează imediat counter-ul:
```verilog
if (!rst_n || count_reset) begin
    cnt <= 16'd1;
    count_val_internal <= 16'b0;
end
```

Această resetare nu afectează registrele de configurație (period, prescale, etc.), ci doar valorile curente ale counter-elor.

## 6. Modulul Generator PWM (`pwm_gen.v`)

### 6.1 Scopul Modulului

Generatorul PWM produce semnalul de ieșire efectiv pe baza valorii counter-ului și a parametrilor de configurație. Implementarea suportă trei moduri de funcționare distincte.

### 6.2 Modurile de Funcționare

Registrul `functions[1:0]` determină modul de operare:

#### 6.2.1 Mod Aliniat Stânga (functions = 2'b00)

```verilog
FUNCTION_ALIGN_LEFT: if (!is_counter_about_to_reset) 
    internal_pwm_comb = (compare1 > count_val);
```

În acest mod:
- PWM pornește de la 1 când counter-ul este resetat
- Rămâne 1 atâta timp cât `count_val < compare1`
- Trece la 0 când `count_val >= compare1`
- Revine la 1 când counter-ul dă overflow

**Factor de umplere**: `compare1 / (period + 1)`

#### 6.2.2 Mod Aliniat Dreapta (functions = 2'b01)

```verilog
FUNCTION_ALIGN_RIGHT: if (!is_counter_about_to_reset) 
    internal_pwm_comb = (count_val >= compare1);
```

În acest mod:
- PWM pornește de la 0 când counter-ul este resetat
- Rămâne 0 atâta timp cât `count_val < compare1`
- Trece la 1 când `count_val >= compare1`
- Revine la 0 când counter-ul dă overflow

**Factor de umplere**: `(period + 1 - compare1) / (period + 1)`

#### 6.2.3 Mod Nealiniat / Range (functions = 2'b1x)

```verilog
FUNCTION_RANGE_BETWEEN_COMPARES: if (!is_counter_about_to_reset) 
    internal_pwm_comb = (count_val >= compare1 && count_val < compare2);
```

În acest mod:
- PWM pornește de la 0
- Trece la 1 când `count_val = compare1`
- Revine la 0 când `count_val = compare2`
- Cerința menționează că acest mod este valabil doar pentru `compare1 < compare2`

**Factor de umplere**: `(compare2 - compare1) / (period + 1)`

### 6.3 Mecanismul de Anticipare a Overflow-ului

```verilog
if ((period > 1) && (count_val+1) == (period-1)) 
    is_counter_about_to_reset <= 1'b1;
```

Flag-ul `is_counter_about_to_reset` se activează cu 2 cicluri înainte de overflow (când counter e la `period-2`). Acest mecanism permite generatorului PWM să anticipeze tranziția și să pregătească valoarea corectă pentru starea inițială a următoarei perioade.

**Raționament**: La ciclu `period-2`, modulul știe că:
- Ciclu curent: `count_val = period-2`
- Ciclu următor: `count_val = period-1`
- Ciclu după următor: `count_val = 0` (overflow)

Astfel poate seta valoarea inițială corectă (1 pentru align-left, 0 pentru align-right) la momentul potrivit.

### 6.4 Logica Combinațională vs. Secvențială

Modulul folosește o abordare hibridă:

```verilog
always @(*) begin
    internal_pwm_comb = ...  // Calculează valoarea dorită
end

always @(posedge clk) begin
    internal_pwm <= internal_pwm_comb;  // Înregistrează valoarea
end
```

Logica combinațională (`internal_pwm_comb`) calculează continuu valoarea PWM dorită pe baza counter-ului și comparatorilor. Logica secvențială înregistrează această valoare la fiecare ciclu de ceas, asigurând stabilitatea semnalului de ieșire și evitând glitch-urile.

### 6.5 Activarea PWM

```verilog
if (pwm_en) begin
    internal_pwm <= internal_pwm_comb;
end
```

Semnalul PWM este actualizat doar când `pwm_en = 1`. Când PWM este dezactivat, ieșirea rămâne "înghețată" la ultima valoare, conform cerințelor.

## 7. Modulul Top (`top.v`)

### 7.1 Integrarea Componentelor

Modulul `top` instanțiază și interconectează toate cele 5 submodule, formând perifericul complet. Acesta definește interfața externă completă:

**Intrări**:
- `clk`, `rst_n`: Ceasul și reset-ul perifericului (10MHz)
- `sclk`, `cs_n`, `mosi`: Semnale SPI de la master
- `pwm_out`: Semnalul PWM generat

**Ieșiri**:
- `miso`: Linia de date SPI către master

### 7.2 Fluxul de Semnale

Fluxul de date prin periferic urmează următoarea cale:

1. **SPI → Decoder**: `spi_bridge` primește bytes prin MOSI și le oferă prin `data_in` + `byte_sync`
2. **Decoder → Regs**: `instr_dcd` generează `read`/`write`, `addr`, `data_write` pentru acces la registre
3. **Regs → Counter/PWM**: Registrele furnizează parametrii de configurație (`period`, `compare1`, etc.)
4. **Counter → PWM**: Counter-ul furnizează `counter_val` pentru generarea PWM
5. **PWM → Exterior**: `pwm_gen` produce semnalul final pe `pwm_out`
6. **Regs → Decoder → SPI**: Pentru citiri, datele revin prin `data_read` → `data_out` → MISO

### 7.3 Observație Importantă

Există o conexiune necompletată în fișierul original:
```verilog
instr_dcd i_instr_dcd (
    .byte_sync(),  // <- port neconectat
    // ...
);
```

Portul `byte_sync` al decodorului nu este conectat la semnalul `byte_sync` de la SPI bridge. Aceasta ar trebui corectată în `.byte_sync(byte_sync)`.

## 8. Particularități ale Implementării

### 8.1 Alegeri de Design

1. **Registrele pe 16 biți sunt accesate doar pe 8 biți low**: Deși arhitectura prevede adresare HIGH/LOW, implementarea actuală scrie doar în `[7:0]`. Aceasta este o limitare a implementării curente.

2. **Counter intern pentru prescaler**: Folosirea unui counter separat (`cnt`) pentru prescaler simplifică logica și oferă control precis asupra ritmului de incrementare.

3. **Auto-clear pentru COUNTER_RESET**: Implementat prin delay counter în modulul `regs`, asigurând comportamentul one-shot necesar.

4. **Anticiparea overflow-ului în PWM**: Mecanismul cu `is_counter_about_to_reset` permite tranziții sincrone și corecte ale semnalului PWM la limitele perioadei.

### 8.2 Considerații de Timing

- Toate modulele (exceptând logica SPI din `spi_bridge`) operează în domeniul de ceas principal (CLK)
- Semnalul `byte_sync` servește ca punct de sincronizare între domeniile SPI și CLK
- Counter-ul se actualizează la fiecare ciclu când este activ, modificările în registre devin vizibile imediat

### 8.3 Testare și Validare

Pentru testarea completă a perifericului, următoarele scenarii ar trebui validate:
- Comunicare SPI: citire/scriere corectă la toate adresele
- Funcționarea counter-ului în ambele direcții și cu diverse valori de prescale
- Generarea corectă a PWM în toate cele 3 moduri
- Auto-clear al COUNTER_RESET
- Modificări dinamice ale configurației în timpul funcționării

## 9. Concluzie

Implementarea realizează un periferic PWM funcțional cu caracteristicile principale descrise în cerință. Arhitectura modulară facilitează înțelegerea, testarea și eventual extinderea funcționalității. Principalele puncte forte ale implementării sunt:

- Separarea clară a responsabilităților între module
- Utilizarea eficientă a prescaler-ului prin shift-uri (2^n)
- Mecanisme de sincronizare între domenii de ceas
- Flexibilitate în configurarea modurilor PWM

Limitările cunoscute (adresare incompletă pe 16 biți, conexiune lipsă în top) pot fi abordate în iterații viitoare ale design-ului.
