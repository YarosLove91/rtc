#include "rtc.h"

RTC::RTC(bool enable_vcd) : clk_running(false), sim_time(0) {
    top = new Vrtc_apb_sim();
    top->pclk = 0;
    top->prst_n = 0;
    std::atomic<bool> clk;

    if (enable_vcd) {
        Verilated::traceEverOn(true);            
        vcd = new VerilatedVcdC();
        top->trace(vcd, 99);                    
        vcd->open("output_new.vcd");             
    } else {
        vcd = nullptr;
    }

    clk_running.store(true);
    clk_thread = std::thread(&RTC::clock_generator, this);
}

RTC::~RTC() {
    clk_running.store(false); 
    std::cout << "sim time " << sim_time << std::endl;
    if (clk_thread.joinable()) {
        clk_thread.join();
    }

    if (vcd) {
        vcd->close(); 
        delete vcd;
    }
    delete top;
}

void RTC::clock_generator() {
    while (clk_running.load()) {
        std::this_thread::sleep_for(std::chrono::milliseconds(5));
        top->pclk = !top->pclk;
        clk.store(top->pclk);
        top->eval();
        if (vcd) vcd->dump(sim_time); 
        sim_time++;
    }
}

void RTC::wait_clk_posedge() {
    while (true) {
        if (clk.load() == 0) { 
            break;
        }
    }
    while (true) {
        if ( clk.load() == 1) { 
            break;
        }
    }
}


void RTC::wait_clk(int cycles) {
    int toggles = 0;
    while (toggles < cycles) {
        wait_clk_posedge();
        toggles++;
    }
}

void RTC::reset() {
    wait_clk_posedge();
    top->prst_n = 0;
    wait_clk(2);
    top->prst_n = 1;
}

void RTC::apb_write(uint32_t addr, uint32_t value) {
    wait_clk_posedge();
    top->s_apb_paddr    = addr;
    top->s_apb_psel     = 1;
    top->s_apb_penable  = 0;
    top->s_apb_pwrite   = 1;
    top->s_apb_pwdata   = value;
    top->s_apb_pstrb    = 0xFF;
    wait_clk_posedge();
    top->s_apb_paddr    = addr;
    top->s_apb_psel     = 1;
    top->s_apb_penable  = 1;
    top->s_apb_pwrite   = 1;
    top->s_apb_pwdata   = value;
    top->s_apb_pstrb    = 0xFF;
    wait_clk_posedge();
    top->s_apb_paddr    = 0;
    top->s_apb_psel     = 0;
    top->s_apb_penable  = 0;
    top->s_apb_pwrite   = 0;
    top->s_apb_pwdata   = 0;
    top->s_apb_pstrb    = 0;
    wait_clk_posedge();
}

uint32_t RTC::apb_read(uint32_t addr) {
    wait_clk_posedge();
    top->s_apb_paddr    = addr;
    top->s_apb_psel     = 1;
    top->s_apb_penable  = 0;
    top->s_apb_pwrite   = 0;
    top->s_apb_pwdata   = 0;
    top->s_apb_pstrb    = 0xFF;
    wait_clk_posedge();
    top->s_apb_paddr    = addr;
    top->s_apb_psel     = 1;
    top->s_apb_penable  = 1;
    top->s_apb_pwrite   = 0;
    top->s_apb_pwdata   = 0;
    top->s_apb_pstrb    = 0xFF;
    wait_clk_posedge();
    top->s_apb_paddr    = 0;
    top->s_apb_psel     = 0;
    top->s_apb_penable  = 0;
    top->s_apb_pwrite   = 0;
    top->s_apb_pwdata   = 0;
    top->s_apb_pstrb    = 0;

    return (uint32_t) top->s_apb_prdata;
}

void RTC::set_time(uint32_t time) {
    apb_write(INIT_CLOCK_ADDR, time);
    apb_write(UPDATE_ADDR, UPDATE_CLOCK_MASK);
}

void RTC::set_date(uint32_t date) {
    apb_write(INIT_DATE_ADDR, date);
    apb_write(UPDATE_ADDR, UPDATE_DATE_MASK);
}

void RTC::calibrate(uint16_t seconds) {
    apb_write(CALIBRE_ADDR, (uint32_t)seconds);
    apb_write(UPDATE_ADDR, UPDATE_CALIBRE_MASK);
}

void RTC::set_alarm(uint32_t date, uint32_t time, uint32_t mask) {
    uint32_t alarm_clock_val =  ( ALARM_CLOCK_EN_MASK | 
                                 ((time << ALARM_CLOCK_DATA_POS)      & ALARM_CLOCK_DATA_MASK) |
                                 ((mask << ALARM_CLOCK_MATCH_MSK_POS) & ALARM_CLOCK_MATCH_MSK_MASK)
                                );

    apb_write(ALARM_CLOCK_ADDR, alarm_clock_val);
    apb_write(ALARM_DATE_ADDR, date);

    apb_write(UPDATE_ADDR, (UPDATE_ALARM_CLOCK_MASK | UPDATE_ALARM_DATE_MASK));
}

uint32_t RTC::get_time() {
    return apb_read(CLOCK_ADDR);
}

uint32_t RTC::get_date() {
    return apb_read(DATE_ADDR);
}

void RTC::print_status() {
    std::cout << "Current Time: 0x" << std::hex << get_time() << std::endl;
    std::cout << "Current Date: 0x" << std::hex << get_date() << std::endl;
}

void RTC::run_cycles(int cycles) {
    wait_clk(cycles);
}

uint32_t RTC::time_to_sec(uint32_t time) {
    int decimal_sec = ((time & 0xff) / 0x10) * 10 + ((time & 0xff) % 0x10);
    int decimal_min = (((((time >> 8) & 0xff))/ 0x10) * 10 + (((time >> 8) & 0xff) ) % 0x10);
    int decimal_hour = ((((time >> 16) & 0xff))/ 0x10) * 10 + ((((time >> 16) & 0xff)) % 0x10);

    return decimal_hour * 3600 + decimal_min * 60 + decimal_sec;
}

bool RTC::wait_alarm(uint32_t date, uint32_t time) {
    while (true) {
        wait_clk_posedge();
        if ((get_date() == date) && (get_time() == time)) {
            uint32_t event_flags = apb_read(EVENT_FLAG_ADDR);
            if(event_flags){
                if(event_flags && EVENT_FLAG_ALARM_MASK){
                    return true;
                }
            }
            return false;
        }
    }
}


void RTC::set_timer(uint32_t time) {   
    uint32_t timer_cfg = TIMER_CFG_EN_MASK | TIMER_CFG_RETRIG_MASK | ((time << TIMER_CFG_TARGET_POS) & TIMER_CFG_TARGET_MASK);
    apb_write(TIMER_CFG_ADDR, timer_cfg);
    apb_write(UPDATE_ADDR, UPDATE_TIMER_MASK);
}

bool RTC::wait_timer(uint32_t time) {
    uint32_t cnt = 0; 
    while (true){
        wait_clk_posedge();
            if(apb_read(EVENT_FLAG_ADDR)){
                break;
            }
    }
    while (true) {
        wait_clk_posedge();
        if(apb_read(EVENT_FLAG_ADDR)){
            if(cnt == time){
                return true;
            }   
            return false; 
        }
        cnt++;
    }
}

void RTC::print_time() {
    uint32_t time = get_time();
    uint32_t date = get_date();
    int hour = (time >> 16) & 0xFF;
    int minute = (time >> 8) & 0xFF;
    int second = time & 0xFF;

    int year = (date >> 16) & 0xFFFF;
    int month = (date >> 8) & 0xFF;
    int day = date & 0xFF;

    std::cout << "Date: " <<std::hex << year << "-" << month << "-" << day
              << " Time: " << hour << ":" << minute << ":" << second << std::endl;
}