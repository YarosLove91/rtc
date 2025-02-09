`timescale 1ns / 1ps

module tb_rtc_top;

	// Testbench signals
	logic clk_i;
	logic rstn_i;

	// Inputs for the RTC module
	logic date_update_i;
	logic [31:0] date_i;
	logic clock_update_i;
	logic [21:0] clock_i;
	logic [9:0] init_sec_cnt_i;
	logic calibre_update_i;
	logic [15:0] calibre_sec_cnt_i;
	logic timer_update_i;
	logic timer_enable_i;
	logic timer_retrig_i;
	logic [16:0] timer_target_i;
	logic alarm_enable_i;
	logic [5:0] alarm_mask_i;
	logic alarm_update_clock_i;
	logic [21:0] alarm_clock_i;
	logic alarm_update_date_i;
	logic [31:0] alarm_date_i;
	logic event_flag_update_i;
	logic [1:0] event_flag_i;

	// Outputs from the RTC module
	logic [31:0] date_o;
	logic [21:0] clock_o;
	logic [15:0] calibre_sec_cnt_o;
	logic [16:0] timer_value_o;
	logic [21:0] alarm_clock_o;
	logic [31:0] alarm_date_o;
	logic [1:0] event_flag_o;
	logic event_o;

	event launch_clock_RTC;

	// Instantiate the rtc_top module
	rtc_top uut (
	.clk_i(clk_i),
	.rstn_i(rstn_i),
	.date_update_i(date_update_i),
	.date_i(date_i),
	.date_o(date_o),
	.clock_update_i(clock_update_i),
	.clock_o(clock_o),
	.clock_i(clock_i),
	.init_sec_cnt_i(init_sec_cnt_i),
	.calibre_update_i(calibre_update_i),
	.calibre_sec_cnt_i(calibre_sec_cnt_i),
	.calibre_sec_cnt_o(calibre_sec_cnt_o),
	.timer_update_i(timer_update_i),
	.timer_enable_i(timer_enable_i),
	.timer_retrig_i(timer_retrig_i),
	.timer_target_i(timer_target_i),
	.timer_value_o(timer_value_o),
	.alarm_enable_i(alarm_enable_i),
	.alarm_mask_i(alarm_mask_i),
	.alarm_update_clock_i(alarm_update_clock_i),
	.alarm_clock_i(alarm_clock_i),
	.alarm_clock_o(alarm_clock_o),
	.alarm_update_date_i(alarm_update_date_i),
	.alarm_date_i(alarm_date_i),
	.alarm_date_o(alarm_date_o),
	.event_flag_update_i(event_flag_update_i),
	.event_flag_i(event_flag_i),
	.event_flag_o(event_flag_o),
	.event_o(event_o)
	);

	// Clock generation for 32768 Hz
	initial begin
		clk_i = 0;
		forever #16384 clk_i = ~clk_i; // 32768 Hz clock
		//forever #15.25 clk_i = ~clk_i; // 32768 Hz clock (1 / 32768 * 2 = 61.035us, half period = 30.517us)
	end

	logic [31:0] count_rtc;
	// Clock generation for 32768 Hz
	initial begin
		count_rtc = 0; // Инициализация счетчика
		@(launch_clock_RTC); // Ждем, пока событие будет вызвано
		forever @(posedge clk_i) begin
			count_rtc <= count_rtc + 1; // Инкремент счетчика на каждом положительном фронте clk_i
		end
	end
	
		// Clock generation for 32768 Hz
	initial begin
		//uut.s_rtc_update_day = 0;
		//forever #1s uut.s_rtc_update_day = ~uut.s_rtc_update_day; // 32768 Hz clock
	end


	// Task for resetting the system
	task reset_system();
	begin
		rstn_i = 0;
		#2ms;
		rstn_i = 1; // Release reset
	end
	endtask

  // Task for updating date
	task update_date(input logic [5:0]	new_date_day,
					 input logic [4:0]	new_date_month,
					 input logic [13:0]	new_date_year);
		begin
			date_i = {2'b00, 
					  new_date_year, 
					  3'b000, 
					  new_date_month, 
					  2'b00, 
					  new_date_day};
			date_update_i = 1;
			#1ms;
			date_update_i = 0;
		end
	endtask

	// Task for updating clock
	task update_clock(input logic [6:0]	new_clock_hours,
					  input logic [7:0]	new_clock_minutes,
					  input logic [7:0]	new_clock_seconds
	);
		begin
			clock_i = {new_clock_hours, 
					   new_clock_minutes, 
					   new_clock_seconds
					   };	// Само время
			init_sec_cnt_i = 9'h00;
			clock_update_i = 1;		// Защелкиваем время
			#1ms;
			clock_update_i = 0;
		end
	endtask

	// Task for updating calibration
	task update_calibration(input logic [15:0] new_calibre);
		begin
			calibre_update_i = 1;
			calibre_sec_cnt_i = new_calibre;
			#1ms;
			calibre_update_i = 0;
		end
	endtask

	// Task for updating timer
	task launch_timer(input logic enable, 
					  input logic retrig,
					  input logic [16:0] target);
		begin
			timer_enable_i = enable;
			timer_retrig_i = retrig;
			timer_target_i = target;
			timer_update_i = 1;
			#1ms;
			timer_update_i = 0;
		end
	endtask

	// Task for updating alarm
	task update_alarm(input logic enable, 
					  input logic [5:0]	mask,
					  //Alarm time
					  input logic [7:0]	alarm_hours,
					  input logic [7:0]	alarm_minutes,
					  input logic [7:0]	alarm_seconds,
					  //Alarm data
					  input logic [5:0]	alarm_day,
					  input logic [4:0]	alarm_month,
					  input logic [13:0]alarm_year);
	
	alarm_clock_i = {alarm_hours, alarm_minutes, alarm_seconds};
	alarm_date_i  = {alarm_year, 3'b000, alarm_month, 2'b00, alarm_day};

		begin
			alarm_enable_i = enable;
			alarm_mask_i = mask;

			alarm_update_clock_i = 1;
			#1ms;
			alarm_update_clock_i = 0;
			alarm_update_date_i = 1;
			#1ms;
			alarm_update_date_i = 0;	
		end
	endtask

	// Task for updating event flags
	task update_event_flags(input logic [1:0] flags);
		begin
			event_flag_i = flags;
			event_flag_update_i = 1;
			#1ms;
			event_flag_update_i = 0;
		end
	endtask

  // Test stimulus
  initial begin
	// Initialize inputs
	date_update_i = 0;
	clock_update_i = 0;
	calibre_update_i = 0;
	timer_update_i = 0;
	timer_enable_i = 0;
	timer_retrig_i = 0;
	alarm_enable_i = 0;
	alarm_update_clock_i = 0;
	alarm_update_date_i = 0;
	event_flag_update_i = 0;

	// Start VCD dump
	$dumpfile("rtc_top.vcd"); // Имя файла VCD
	$dumpvars(0,
				clk_i, 
				clock_o,
				timer_value_o,
				uut.i_rtc_clock.r_seconds, 
				uut.i_rtc_clock.r_minutes, 
				uut.i_rtc_clock.r_hours,
				uut.i_rtc_clock.r_timer,
				event_o, 
				tb_rtc_top.uut.i_rtc_date.date_o,
				count_rtc);

	// Reset the system
	reset_system();
	#1ms ->launch_clock_RTC;
	// 1ms
	// Задаем время
	update_clock(6'h23,
	 			 8'h58,
	 			 8'h30);

	// 1ms + 2ms
	// Задаем дату
	update_date(6'h03,			// День 
				6'h06, 			// Месяц
				14'h2010		// Год
				);
	// 1 ms + 2 ms + 2ms

	// 1 ms + 2 ms + 2ms + 1ms
	update_calibration(16'h77D1); // 
	// 1 ms + 2 ms + 2ms + 1ms + 1 ms

	//Включаем будильник
	update_alarm(1'b1, 					
				 6'b111111,				// Alarm mask
				 7'h00,7'h01,7'h30, 	// HH:MM:SS
				 6'h04,5'h06,16'h2010	// day:month:year
				); 

	// Test event flag update
	//update_event_flags(2'b00); // Example event flag
	// Включаем таймер
	launch_timer(1, 			// 1 - enable, 0 - disable
				 1, 			// 0 - one shot mode, 1 - infinity mode
				 17'h0000		// Счет до. Используется для event ов
				 );
	#10s;
	$finish;
  end

  // Monitor outputs
  initial begin
	$monitor("Time: %0t | clock_o: %h | date_o: %h | alarm_clock_o : %h | alarm_date_o : %h | event_flag_o: %b | event_o: %b",
			 $time, clock_o, date_o, alarm_clock_o, alarm_date_o, event_flag_o, event_o);
  end

endmodule // tb_rtc_top
