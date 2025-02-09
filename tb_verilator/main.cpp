#include "rtc.h"

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    RTC rtc(VM_TRACE);

    rtc.reset();

    uint32_t timer_period = 0x96;
    rtc.set_timer(timer_period);

    uint32_t alarm_date = 0x20241215;
    uint32_t alarm_time = 0x12559;
    uint32_t alarm_flags = 0x0;
    rtc.set_alarm(alarm_date, alarm_time, alarm_flags);

    uint32_t calibration_value = 9;
    rtc.calibrate(calibration_value);

    uint32_t initial_time = 0x12345;
    uint32_t initial_date = 0x20241215;
    rtc.set_time(initial_time);
    rtc.set_date(initial_date);
    rtc.print_time(); 

    uint32_t start_time = rtc.get_time();

    uint32_t wait_cycles = 1000;
    rtc.wait_clk(wait_cycles);

    uint32_t end_time = rtc.get_time();


    start_time = rtc.time_to_sec(start_time);
    end_time = rtc.time_to_sec(end_time);
    

    //checking the time account
    if (end_time == start_time + (wait_cycles/(calibration_value + 1)))
    {
        std::cout << "Check [0] - OK" << std::endl;
    }
    else
    {
        std::cout << "Check [0] - FAIL" << std::endl;
        std::cout << "Time is not correct:" << std::endl;
        std::cout << "start_time: 0x" << start_time << std::hex << " end_time: 0x" << end_time << std::hex << std::endl;
        rtc.wait_clk(10);
        return 1;
    }
    // assert(end_time == start_time + (wait_cycles/(calibration_value + 1)) && "Time is not correct");

    //alarm check
    bool alarm = rtc.wait_alarm(alarm_date, alarm_time);
    assert(alarm == true && "Alarm is not correct");

    rtc.wait_clk(100);

    //timer check
    bool timer = rtc.wait_timer(timer_period);
    assert(timer == true && "Timer is not correct");

    rtc.print_time(); 

    #ifdef ENABLE_COVERAGE
    Verilated::threadContextp()->coveragep()->write("logs/coverage.dat");
    #endif
    return 0;
}