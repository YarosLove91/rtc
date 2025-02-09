module rtc_apb_sim (
    input  logic        pclk         ,
    input  logic        prst_n       ,
    input  logic [31:0] s_apb_paddr  ,
    input  logic        s_apb_psel   ,
    input  logic        s_apb_penable,
    input  logic        s_apb_pwrite ,
    input  logic [31:0] s_apb_pwdata ,
    input  logic [ 3:0] s_apb_pstrb  ,
    output logic        s_apb_pready ,
    output logic [31:0] s_apb_prdata ,
    output logic        s_apb_pslverr,
    output logic        irq
);


APB #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) s_apb();

always_comb begin
    s_apb.paddr     = s_apb_paddr;
    s_apb.psel      = s_apb_psel;
    s_apb.penable   = s_apb_penable;
    s_apb.pwrite    = s_apb_pwrite;
    s_apb.pwdata    = s_apb_pwdata;
    s_apb.pstrb     = s_apb_pstrb;
    s_apb_pready    = s_apb.pready;
    s_apb_prdata    = s_apb.prdata;
    s_apb_pslverr   = s_apb.pslverr;
end

rtc_apb #(.APB_ADDR_W(32)) i_rtc_apb (.pclk(pclk), .prst_n(prst_n), .irq(irq), .s_apb(s_apb));


endmodule : rtc_apb_sim