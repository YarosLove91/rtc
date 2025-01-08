# Регистровая карта дизайна часов реального времени
В документе приведены регистры часов реального времени и побитовое описание флагов.

Общий переченень регистров представлен дизайна часов реального времени`rtc_pulp` в таблице 1.

Таблица 1 - Общий перечень регистров RTC.

|№|Регистр|Смещение| Биты |           Описание        |Доступ|
|-|-----------|----|------|---------------------------|------|
|1|DATA       |0x00|  32  | Входное значение даты     |  R/W |
|2|CLOCK      |0x04|  22  | Входное значение секунд   |  R/W |
|3|ALARM_DATE |0x08|  31  | Входное значение будильника| R/W |
|4|ALARM_CLOCK|0x0C|  22  | Входное значение будильника| R/W |
|5|TIMER      |0x10|  16  | Время до события           | R/W | 
|6|CALIBRE    |0x14|  16  | Точная подстройка секунд   | R/W |
|7|EVENT_FLAG |0x18|  2   | Управление флагом EVENT    | R/W |
|8|UPDATE     |0x1C| [WIP]|      [WIP]                 | W   |


## 1 DATE - Date register
Регистр содержащий дату в BCD формате.
Размерность: 32 бита
Диапазон: 0x00000000 до 0xFFFFFFFF

Таблица согласно файлу `RTC.h`

|№ |Данные         |Кол-во бит|№ бита|
|--|---------------|----------|------|
| 1|RTC_DATE_DATA  |     1    |[31:0]|

```verilog
    input logic [31:0]  date_i,
    ...
    assign s_day    = date_i[5:0];
    assign s_month  = date_i[12:8];
    assign s_year   = date_i[29:16];
```

## 2 CLOCK - Clock calendar register
Регистр содержит дату для будильника. Данные представлены в .BCD формате.
</br>Размерность: 22 + 10 бит.</el>

|№   |Данные         |Кол-во бит|№ бита |
|-|---------------|----------|-------|
|1|RTC_CLOCK_DATA    |    22    |[21:0] |
|2|RTC_CLOCK_INIT_SEC_CNT| 10   |[31:22]|

```verilog
    input logic [21:0]  clock_i,
    ...
    assign s_seconds = clock_i[7:0];
    assign s_minutes = clock_i[15:8];
    assign s_hours   = clock_i[21:16];
```

## 3 TIMER - Timer count down register

|№ |Данные         |Кол-во бит|№ бита |
|--|---------------|----------|-------|
| 1|RTC_TIMER_EN   |     1    |  [31] |
| 2|RTC_TIMER_RETRIG|    1    |  [30] |
| 3|RTC_TIMER_CMP  |    10    | [16:0]|

```verilog 
    input logic [16:0]  timer_target_i,
```

## 4 ALARM_DATE - Date register
Регистр содержит дату для будильниика. Данные представлены в формате BCD.
Размерность: 32 бита
Диапазон: 0x00000000 до 0xFFFFFFFF.

|№ |Данные                |Кол-во бит|№ бита |
|--|----------------------|----------|-------|
| 1|RTC_ALARM_DATE_DATE   |     1    |[31:0] |


```verilog
    input logic [31:0]  alarm_date_i,
    ...
    assign s_alarm_day   = alarm_date_i[5:0];
    assign s_alarm_month = alarm_date_i[12:8];
    assign s_alarm_year  = alarm_date_i[29:16];
```
## 5 ALARM_CLOCK - Timer count down register

Весь регистр это данные для записи
Размерность: 22 + 6 + 1
Диапазон: 0x00000000 до 0xFFFFFFFF


|№ |Данные         |Кол-во бит|№ бита |
|--|---------------|----------|-------|
| 1|RTC_ALARM_CLOCK_DATA|    |[21:0] |
| 2|RTC_ALARM_CLOCK_MATCH_MASK|  6  |[29:24] |
| 3|RTC_ALARM_CLOCK_EN|  1  | [31] |

```verilog
    input logic [21:0]  alarm_clock_i,
    ...
    assign s_alarm_seconds = alarm_clock_i[7:0];
    assign s_alarm_minutes = alarm_clock_i[15:8];
    assign s_alarm_hours   = alarm_clock_i[21:16];
```

## 6 EVENT_FLAG - Timer and alarm event flag register
|№ |Данные         |Кол-во бит|№ бита|
|--|---------------|----------|------|
| 1|RTC_EVENT_FLAG_TIMER| 2   |[2:1] |
| 2|RTC_EVENT_FLAG_ALARM| 1   |  [0] |

```verilog
    input logic         event_flag_update_i,
    input logic [1:0]   event_flag_i,
```

## 7 Калибровочный регистр 
|№ |Данные         |Кол-во бит|№ бита|
|--|---------------|----------|------|
| 1|CALIBRATE_RATE |    16    |[15:0]|


```verilog
    input logic [15:0]  calibre_sec_cnt_i,
```

## 8 Сигналы выведенные в отдельный регистр "update"

|№ |Данные                   |Кол-во бит|№ бита |
|--|-------------------------|----------|-------|
| 1|RTC_UPDATE_CLOCK         |     1    |  [0]  |
| 2|RTC_UPDATE_DATE          |     1    |  [1]  |
| 3|RTC_UPDATE_TIMER         |     1    |  [2]  |
| 4|RTC_UPDATE_CALIBRE       |     1    |  [3]  |
| 5|RTC_UPDATE_EVENT         |     1    |  [4]  |
| 6|RTC_UPDATE_ALL           |     1    |  [6]  |

TODO:Доделать описание регистра.

```verilog
    input logic         date_update_i,
    input logic         clock_update_i,
    input logic         calibre_update_i,
    input logic         timer_update_i,
    input logic         event_flag_update_i,
```