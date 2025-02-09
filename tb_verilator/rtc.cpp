#include "rtc.h"

RTC::RTC(bool enable_vcd) : clk_running(false), sim_time(0) {
    top = new Vrtc_top();
    top->clk_i = 0;
    top->rstn_i = 0;
    std::atomic<bool> clk;

    if (enable_vcd) {
        Verilated::traceEverOn(true);            
        vcd = new VerilatedVcdC();
        top->trace(vcd, 99);                    
        vcd->open("output.vcd");             
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
        top->clk_i = !top->clk_i;
        clk.store(top->clk_i);
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
    top->rstn_i = 0;
    wait_clk(2);
    top->rstn_i = 1;
}

void RTC::set_time(uint32_t time) {
    wait_clk_posedge();
    top->clock_update_i = 1;
    top->clock_i = time;
    wait_clk_posedge();
    top->clock_update_i = 0;
}

void RTC::set_date(uint32_t date) {
    wait_clk_posedge();
    top->date_update_i = 1;
    top->date_i = date;
    wait_clk_posedge();
    top->date_update_i = 0;
}

void RTC::calibrate(uint16_t seconds) {
    wait_clk_posedge();
    top->calibre_update_i = 1;
    top->calibre_sec_cnt_i = seconds;
    wait_clk_posedge();
    top->calibre_update_i = 0;
}

void RTC::set_alarm(uint32_t date, uint32_t time, uint32_t mask) {
    wait_clk_posedge();
    top->alarm_enable_i = 1;
    top->alarm_update_date_i = 1;
    top->alarm_date_i = date;
    top->alarm_update_clock_i = 1;
    top->alarm_clock_i = time;
    top->alarm_mask_i = mask;
    wait_clk_posedge();
    top->alarm_update_date_i = 0;
    top->alarm_update_clock_i = 0;
}

uint32_t RTC::get_time() const {
    return top->clock_o;
}

uint32_t RTC::get_date() const {
    return top->date_o;
}

void RTC::print_status() const {
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
            if(top-> event_o){
                wait_clk_posedge();
                if((top -> event_flag_o && 0x1 )){
                    return true;
                }
            }
            return false;
        }
    }
}


void RTC::set_timer(uint32_t time) { 
    wait_clk_posedge();
    top->timer_enable_i = 1;
    top->timer_update_i = 1;
    top->timer_target_i = time;
    top->timer_retrig_i = 1;
    wait_clk_posedge();
    wait_clk_posedge();
    top->timer_update_i = 0;

}

bool RTC::wait_timer(uint32_t time) {
    uint32_t cnt = 0; 
    while (true){
        wait_clk_posedge();
            if(top-> event_o){
                break;
            }
    }
    while (true) {
        wait_clk_posedge();
        if(top-> event_o){
            if(cnt == time ){
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