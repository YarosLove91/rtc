module rtc_apb
#(
    parameter int APB_ADDR_W = 32
)
(
    input  logic pclk,
    input  logic prst_n,
    output logic irq,
    APB.Slave   s_apb
);

// regs map (multiply by 4 to get address)
localparam int INIT_DATE_IDX    = 0              ; // r/w
localparam int DATE_IDX         = 1              ; // r/o
localparam int INIT_CLOCK_IDX   = 2              ; // r/w
localparam int CLOCK_IDX        = 3              ; // r/o
localparam int INIT_SEC_CNT_IDX = 4              ; // r/w
localparam int ALARM_DATE_IDX   = 5              ; // r/w
localparam int ALARM_CLOCK_IDX  = 6              ; // r/w
localparam int TIMER_CFG_IDX    = 7              ; // r/w
localparam int TIMER_VAL_IDX    = 8              ; // r/o
localparam int CALIBRE_IDX      = 9              ; // r/w
localparam int EVENT_FLAG_IDX   = 10             ; // w1c
localparam int UPDATE_IDX       = 11             ; // w1u (write 1 update)
localparam int APPLIED_IDX      = 12             ; // r/o
localparam int REGS_QTY         = APPLIED_IDX + 1;

// apb regs params
localparam int                    REGS_OFFSET = 4         ; // 32bit aligned addresses
localparam int                    APB_DATA_W  = APB_ADDR_W;
localparam logic [APB_ADDR_W-1:0] BASE_ADDR   = 'd0       ; // TODO: clarify what address

// read only regs indexes set for apb regs module
function bit [REGS_QTY-1:0] set_read_only_regs();
    bit [REGS_QTY-1:0] res;
    res = '0;
    res[APPLIED_IDX]    = 1;
    res[DATE_IDX]       = 1;
    res[CLOCK_IDX]      = 1;
    res[TIMER_VAL_IDX]  = 1;
    return res;
endfunction : set_read_only_regs

// write '1' to clear regs indexes set for apb regs module
function bit [REGS_QTY-1:0] set_write_to_clear_regs();
    bit [REGS_QTY-1:0] res;
    res = '0;
    res[EVENT_FLAG_IDX] = 1;
    return res;
endfunction : set_write_to_clear_regs

// write '1' to clear regs indexes set for apb regs module
function bit [REGS_QTY-1:0] set_write_to_upd_regs();
    bit [REGS_QTY-1:0] res;
    res = '0;
    res[UPDATE_IDX] = 1;
    return res;
endfunction : set_write_to_upd_regs

localparam bit [REGS_QTY-1:0] READ_ONLY       = set_read_only_regs();
localparam bit [REGS_QTY-1:0] WRITE_TO_CLEAR  = set_write_to_clear_regs();
localparam bit [REGS_QTY-1:0] WRITE_TO_UPDATE = set_write_to_upd_regs();


// structs for registers bit mapping
typedef struct packed {
    logic [31:22]    reserved;
    logic [21: 0]    data;
} clock_t;

typedef struct packed {
    logic [31:10]    reserved;
    logic [ 9: 0]    init_sec_cnt;
} init_sec_cnt_t;

typedef struct packed {
    logic           en;         // 31
    logic           reserved_1; // 30
    logic [ 5: 0]   match_mask; // 29...24
    logic [23:22]   reserved_0; // 23...22
    logic [21: 0]   data;       // 21...0
} alarm_clock_t;

typedef struct packed {
    logic           en;         // 31
    logic           retrig;     // 30
    logic [29:17]   reserved;   // 29...17
    logic [16:0]    target;     // 16...0
} timer_cfg_t;

typedef struct packed {
    logic [31:17]   reserved;
    logic [16:0]    value;
} timer_val_t;

typedef struct packed {
    logic [31:16] reserved;
    logic [15: 0] calibre_sec_cnt;
} calibre_t;

typedef struct packed {
    logic [31:2]    reserved;   // 31:2
    logic           timer_flag; // 1
    logic           alarm_flag; // 0
} event_flag_t;


typedef struct packed {
    logic [31:6]    reserved;
    logic           upd_calibre;      // 5
    logic           upd_timer;        // 4
    logic           upd_alarm_clock;  // 3
    logic           upd_alarm_date;   // 2
    logic           upd_clock;        // 1
    logic           upd_date;         // 0
} update_t;

typedef struct packed {
    logic [31:5]    reserved;
    logic           applied_calibre;      // 4
    logic           applied_alarm_clock;  // 3
    logic           applied_alarm_date;   // 2
    logic           applied_clock;        // 1
    logic           applied_date;         // 0
} applied_t;

// struct for all timer regs
typedef struct packed {
    applied_t       applied;        // r/o
    update_t        update;         // w1u
    event_flag_t    event_flag_o;   // w1c
    event_flag_t    event_flag_i;   // w1c
    calibre_t       calibre;        // r/w
    timer_val_t     timer_val;      // r/o
    timer_cfg_t     timer_cfg;      // r/w
    alarm_clock_t   alarm_clock;    // r/w
    logic   [31:0]  alarm_date;     // r/w
    init_sec_cnt_t  init_sec_cnt;   // r/w
    clock_t         clock;          // r/o
    clock_t         init_clock;     // r/w
    logic   [31:0]  date;           // r/o
    logic   [31:0]  init_date;      // r/w
} regs_t;

typedef struct {
    logic [15:0] calibre_sec_cnt;
    logic [21:0] alarm_clock;
    logic [31:0] alarm_date;
} actual_regs_t;

// signals declarations
regs_t          all_regs;
actual_regs_t   actual_regs;
logic [REGS_QTY - 1:0][APB_DATA_W - 1:0] reg_inputs;
logic [REGS_QTY - 1:0][APB_DATA_W - 1:0] reg_outputs;


// apb regs
apb_regs_intf #(
    .NO_APB_REGS    (REGS_QTY       ),   // number of registers
    .APB_ADDR_WIDTH (APB_ADDR_W     ),   // address width of `paddr`
    .ADDR_OFFSET    (REGS_OFFSET    ),   // address offset in bytes
    .APB_DATA_WIDTH (APB_DATA_W     ),   // data width of the registers
    .REG_DATA_WIDTH (APB_DATA_W     ),
    .READ_ONLY      (READ_ONLY      ),
    .WRITE_TO_CLEAR (WRITE_TO_CLEAR ),
    .WRITE_TO_UPDATE(WRITE_TO_UPDATE)
) apb_regs (
    .pclk_i     (pclk       ),
    .presetn_i  (prst_n     ),
    .slv        (s_apb      ),
    .base_addr_i(BASE_ADDR  ),   // base address of the registers
    .reg_init_i (reg_inputs ),   // values for the r/0 or w1c registers
    .reg_q_o    (reg_outputs)    // actual regs' values
);

always_comb begin : regs_handler
    // r/w and w1c
    all_regs.update       = reg_outputs[UPDATE_IDX];
    all_regs.event_flag_o = reg_outputs[EVENT_FLAG_IDX];
    all_regs.calibre      = reg_outputs[CALIBRE_IDX];
    all_regs.timer_cfg    = reg_outputs[TIMER_CFG_IDX];
    all_regs.alarm_clock  = reg_outputs[ALARM_CLOCK_IDX];
    all_regs.alarm_date   = reg_outputs[ALARM_DATE_IDX];
    all_regs.init_sec_cnt = reg_outputs[INIT_SEC_CNT_IDX];
    all_regs.init_clock   = reg_outputs[INIT_CLOCK_IDX];
    all_regs.init_date    = reg_outputs[INIT_DATE_IDX];

    reg_inputs                  = '0; // default assignment
    // r/o, w1c
    reg_inputs[APPLIED_IDX]     = all_regs.applied;
    reg_inputs[EVENT_FLAG_IDX]  = all_regs.event_flag_i;
    reg_inputs[TIMER_VAL_IDX]   = all_regs.timer_val;
    reg_inputs[CLOCK_IDX]       = all_regs.clock;
    reg_inputs[DATE_IDX]        = all_regs.date;
end

always_comb begin : applied_handler
    all_regs.applied.applied_calibre     = (actual_regs.calibre_sec_cnt  == all_regs.calibre.calibre_sec_cnt);
    all_regs.applied.applied_alarm_clock = (actual_regs.alarm_clock      == all_regs.alarm_clock.data);
    all_regs.applied.applied_alarm_date  = (actual_regs.alarm_date       == all_regs.alarm_date);
    all_regs.applied.applied_clock       = (all_regs.clock               == all_regs.init_clock);
    all_regs.applied.applied_date        = (all_regs.date                == all_regs.init_date);
    all_regs.applied.reserved            = '0;
end

always_comb irq = |all_regs.event_flag_o;


rtc_top i_rtc_top (
    .clk_i               (pclk                              ),
    .rstn_i              (prst_n                            ),
    .date_update_i       (all_regs.update.upd_date          ),
    .date_i              (all_regs.init_date                ),
    .date_o              (all_regs.date                     ),   // TODO: clarify for what are output values of regs
    .clock_update_i      (all_regs.update.upd_clock         ),
    .clock_o             (all_regs.clock.data               ),
    .clock_i             (all_regs.init_clock.data          ),
    .init_sec_cnt_i      (all_regs.init_sec_cnt.init_sec_cnt),
    .calibre_update_i    (all_regs.update.upd_calibre       ),
    .calibre_sec_cnt_i   (all_regs.calibre.calibre_sec_cnt  ),
    .calibre_sec_cnt_o   (actual_regs.calibre_sec_cnt       ),
    .timer_update_i      (all_regs.update.upd_timer         ),
    .timer_enable_i      (all_regs.timer_cfg.en             ),
    .timer_retrig_i      (all_regs.timer_cfg.retrig         ),
    .timer_target_i      (all_regs.timer_cfg.target         ),
    .timer_value_o       (all_regs.timer_val.value          ),
    .alarm_enable_i      (all_regs.alarm_clock.en           ),
    .alarm_mask_i        (all_regs.alarm_clock.match_mask   ),
    .alarm_update_clock_i(all_regs.update.upd_alarm_clock   ),
    .alarm_clock_i       (all_regs.alarm_clock.data         ),
    .alarm_clock_o       (actual_regs.alarm_clock           ),
    .alarm_update_date_i (all_regs.update.upd_alarm_date    ),
    .alarm_date_i        (all_regs.alarm_date               ),
    .alarm_date_o        (actual_regs.alarm_date            ),
    .timer_flag          (all_regs.event_flag_i.timer_flag  ),
    .alarm_flag          (all_regs.event_flag_i.alarm_flag  )
);


endmodule : rtc_apb