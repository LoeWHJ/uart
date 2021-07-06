`timescale 1ns / 1ps
//==================================================================================================
//  Filename      : clock_s.v
//  Created On    : 2021-05-11
//  Version       : V 1.0
//  Author        : 
//  Description   : Second timer
//  Modification  :
//设计目标：以clk为基准，设计一个秒计数器，在指定的计数值产生中断，实时输出当前的秒数计数值
//     clk是时钟输入，频率为100MHz。
//     rst_n是异步复位输入，低电平有效。
//     start是启动信号，开始记录clk周期数，end是结束信号。timestamp不受start和end信号印象。
//     工作模式：收到start后， timer_compare/timer_command 开始记录clk周期数，周期数 * 10ns = 时间长度
//设计思路：
//首先，时钟频率为100MHz，即计数100_000_000为1秒,一个周期10ns,100个周期1us,100000周期1ms,,1 毫秒=1000000 纳秒
//输出：秒为单位  timer_compare    timer_wait
//==================================================================================================


module clock_counts  #(
    parameter [31:0] SECONDS       = 32'd10   , //测试，等待10个时钟周期    32'd99999999 //100000000-1 
    parameter [31:0] COMPARE_OVER  = 32'd100000000//超时的时间，10000个时钟周期，100000ns=100us=0.1ms   1s
    )
    (
    input                               clk                        ,
    input                               rst_n                      ,
    input                               start_counter              ,//等待 计时开始
    input                               start_counter_compare      ,//比较数据计时开始
    input                               end_counter_compare        ,   
    input                  [  31:0]     timer_wait                 , //需要等待的时钟周期数
     
    output   wire          [  31:0]     timer_compare           ,//比较数据，输出的比较时间
    output   wire                       time_compare_over       ,//比较超时，标志
    output   wire                       time_count_done         ,//表示到达等待时间
    output   wire          [  31:0]     timestamp                   
    );
    
   //////////////////**********对比**********/////////////////////   
    reg   time_compare_over_reg;
    assign time_compare_over  =  time_compare_over_reg;
    reg   start_com_reg;
    wire    [  31:0]  timer_compare_reg;
    assign timer_compare = timer_compare_reg;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin       
            start_com_reg <= 1'b0; 
        end                    
        else begin
            if (start_counter_compare ) begin
                start_com_reg  <= 1'b1;
            end
            else  start_com_reg <= 1'b0;
        end
    end
    /////////////////**********对比**********///////////////////////////////////
    
    ///////////////************等待***************///////////////////////////////
    reg    [  31:0]  timer_wait_reg;
    reg   start_reg;
    reg    time_count_done_reg;
    assign time_count_done = time_count_done_reg;
    //所存timer_wait的值
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            timer_wait_reg <= 32'd0;  
        end 
        else begin
            if (start_counter && time_count_done == 1'b0) begin
                timer_wait_reg <= timer_wait;
            end
            else  timer_wait_reg <= 32'd0;  
        end
    end
 
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            start_reg <= 1'b0;  
        end 
        else begin
            if (start_counter) begin
                start_reg <= 1'b1;
            end
            else  start_reg <= 1'b0;
        end
    end
    
    parameter [3:0]  IDLE    = 4'b0000;
    parameter [3:0]  TIME    = 4'b0001;
    reg     [3:0]      State_current;
    reg     [3:0]      State_next;
    
    reg     [31:0]     wait_period_times   ;//等待的时钟周期数
    reg     [31:0]     wait_second   ;

    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)
            State_current <= IDLE;
        else
            State_current <= State_next;
    end
    
    always@(*)begin
        case(State_current)
            IDLE:
                if(start_counter && time_count_done == 1'b0)
                    State_next = TIME;
                else
                    State_next = IDLE;
            TIME:
                if(time_count_done == 1'b1)  
                    State_next = IDLE;
                else
                    State_next = TIME;
            default:State_next = IDLE;
        endcase
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            wait_period_times    <= 32'd0;
            wait_second          <= 32'd0;   
            time_count_done_reg  <= 1'b0;
        end
        else begin
            case (State_next)
                IDLE: begin
//                    compare_period_times <= 32'd0;
                    wait_period_times    <= 32'd0;   
                    wait_second          <= 32'd0;   
                    time_count_done_reg  <= 1'b0; 
                end
                TIME: begin
                    wait_period_times    <= wait_period_times + 32'd1; 
                    if (wait_period_times == timer_wait) begin  //判断是否到达等待时间
                        time_count_done_reg <= 1'b1;
                    end
                    else begin
                        time_count_done_reg <= 1'b0;
                    end                     
                end
                default: begin
                    wait_period_times    <= 32'd0;  
                    time_count_done_reg  <= 1'b0;
                end
            endcase
        end
    end
    ///////////////************等待***************////////////////////////////

/////////////////////对比/////////////////////////////////////////////
    parameter [3:0]  IDLE_1    = 4'b0000;
    parameter [3:0]  TIME_1    = 4'b0001;
    reg     [3:0]      State_current_1;
    reg     [3:0]      State_next_1;    
    
    reg     [31:0]     compare_period_times;//对比的周期数
    assign   timer_compare_reg = compare_period_times;

    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)
            State_current_1 <= IDLE_1;
        else
            State_current_1 <= State_next_1;
    end
    
    always@(*)begin
        case(State_current_1)
            IDLE_1:
                if(start_counter_compare )
                    State_next_1 = TIME_1;
                else
                    State_next_1 = IDLE_1;
            TIME:
                if(end_counter_compare)  
                    State_next_1 = IDLE_1;
                else
                    State_next_1 = TIME_1;
            default:State_next_1 = IDLE_1;
        endcase
    end
    
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            compare_period_times    <= 32'd0;
            time_compare_over_reg  <= 1'b0; 
        end
        else begin
            case (State_next)
                IDLE: begin
                    compare_period_times <= 32'd0;
                    time_compare_over_reg  <= 1'b0; 
                end
                TIME: begin
                    compare_period_times    <= compare_period_times + 32'd1;     
                    if (compare_period_times == COMPARE_OVER) begin
                        time_compare_over_reg  <= 1'b1;
                    end                                    
                end
                default: begin
                    compare_period_times    <= 32'd0; 
                    time_compare_over_reg  <= 1'b0; 
                end
            endcase
        end
    end    

///////////////////对比///////////////////////////////////////////////


////////////////// counter for clk to timestamp///////////////////////
    reg     [31:0]     cnt;
    reg     [31:0]     cnt_s;
    
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt   <= 32'd0;   
            cnt_s <= 32'd0;   
        end 
        else begin
            if (cnt==SECONDS) begin
                cnt <= 32'd0;    
                cnt_s <= cnt_s + 1'd1;
            end
            else cnt <= cnt + 1'd1;      
        end
    end
    assign timestamp =   cnt_s;   

endmodule

