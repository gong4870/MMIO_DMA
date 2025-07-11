`default_nettype none

module data_checker #(
    parameter DATA_WIDTH = 64
)(
    // 클럭/리셋
    input  wire                  clk,
    input  wire                  reset,

    // AXI4-Stream Slave (입력)
    input  wire [DATA_WIDTH-1:0] S_AXIS_TDATA,
    input  wire                  S_AXIS_TVALID,
    input  wire                  S_AXIS_TLAST,
    output reg                   S_AXIS_TREADY,

    // AXI4-Stream Master (출력)
    output wire [DATA_WIDTH-1:0] M_AXIS_TDATA,
    output reg                   M_AXIS_TVALID,
    output reg                   M_AXIS_TLAST,
    input  wire                  M_AXIS_TREADY,
    
    // BRAM B 포트 인터페이스
    output reg  [31:0]  bram_addrb,
    output wire [63:0]  bram_dinb,     //don't use
    input  wire [63:0]  bram_doutb,
    output reg          bram_enb,
    output wire [7:0]   bram_web      //don't use
//    output wire         bram_rstb
);
    
    localparam IDLE    = 0,
               STORE   = 1,
               PROCESS = 2,
               WAIT    = 3,
               SEND    = 4;
               
    reg [3:0] state, n_state; 
    reg [9:0] count; 
    
    reg ena, enb, wea;
    reg [5:0] addra, addrb;
    reg [63:0] dina;
    wire [63:0] doutb;
    
    reg o_ena, o_enb, o_wea;
    reg [5:0] o_addra, o_addrb;
    reg [63:0] o_dina;
          
//    assign bram_rstb = 1; 
    assign bram_web  = 8'b0;
    assign bram_dinb = 64'b0;
    
    reg [15:0] p_count;
    reg [15:0] q_count;
               
    data_Mem U1(
        .clka(clk),    // input wire clka
        .ena(ena),      // input wire ena
        .wea(wea),      // input wire [0 : 0] wea
        .addra(addra),  // input wire [5 : 0] addra
        .dina(dina),    // input wire [63 : 0] dina
        .clkb(clk),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(addrb),  // input wire [5 : 0] addrb
        .doutb(doutb)  // output wire [63 : 0] doutb
    );    
    
    output_Mem U2(
        .clka(clk),    // input wire clka
        .ena(o_ena),      // input wire ena
        .wea(o_wea),      // input wire [0 : 0] wea
        .addra(o_addra),  // input wire [5 : 0] addra
        .dina(o_dina),    // input wire [63 : 0] dina
        .clkb(clk),    // input wire clkb
        .enb(o_enb),      // input wire enb
        .addrb(o_addrb),  // input wire [5 : 0] addrb
        .doutb(M_AXIS_TDATA)  // output wire [63 : 0] doutb
    );            

    always@(posedge clk, negedge reset)begin
        if(!reset) begin
            state <= IDLE;
        end else begin
            state <= n_state;
        end
    end
    
    always@(*)begin
        n_state = state;
        S_AXIS_TREADY = 0;
        M_AXIS_TVALID = 0;
        M_AXIS_TLAST  = 0;
        
        case(state)
            IDLE: begin
                S_AXIS_TREADY = 1;
                M_AXIS_TVALID = 0;
                M_AXIS_TLAST  = 0;
                if(S_AXIS_TVALID)begin
                    n_state = STORE;
                end
            end
            
            STORE: begin
                S_AXIS_TREADY = 1;
                M_AXIS_TVALID = 0;
                M_AXIS_TLAST  = 0;
                if(S_AXIS_TLAST)begin
                    n_state = PROCESS;
                end
            end
            
            PROCESS: begin
                S_AXIS_TREADY = 0;
                M_AXIS_TVALID = 0;
                M_AXIS_TLAST  = 0;
                if(q_count == 20)begin
                    n_state = WAIT;
                end
            end
            
            WAIT: begin
                S_AXIS_TREADY = 0;
                M_AXIS_TVALID = 1;
                M_AXIS_TLAST  = 0;
                if(M_AXIS_TREADY)begin
                    n_state = SEND;
                end
            end

            SEND: begin
                S_AXIS_TREADY = 0;
                M_AXIS_TVALID = 1;
                
                if(count == 1 && M_AXIS_TREADY)begin
                    M_AXIS_TLAST = 1;
                end else
                if(count == 0 && M_AXIS_TREADY)begin
                    n_state = IDLE;
                    M_AXIS_TLAST = 1;
                end
            end
            
            default: n_state = IDLE;
        endcase
    end
    

    always@(posedge clk, negedge reset)begin
        if(!reset)begin
            ena   <= 0;
            enb   <= 0;
            wea   <= 0;
            addra <= 0;
            addrb <= 0;
            dina  <= 0;
            count <= 0;
            
            o_ena   <= 0;
            o_enb   <= 0;
            o_wea   <= 0;
            o_addra <= 0;
            o_addrb <= 0;
            o_dina  <= 0;
            
            p_count    <= 0;
            q_count    <= 0;
            bram_enb   <= 0;
            bram_addrb <= 0;
        end
        else if(state == IDLE)begin
            ena   <= 0;
            enb   <= 0;
            wea   <= 0;
            addra <= 0;
            addrb <= 0;
            dina  <= 0;
            count <= 0;
            
            o_ena   <= 0;
            o_enb   <= 0;
            o_wea   <= 0;
            o_addra <= 0;
            o_addrb <= 0;
            o_dina  <= 0;
            
            p_count    <= 0;
            q_count    <= 0;
            bram_enb   <= 0;
            bram_addrb <= 0;
        end
        else if(state == STORE)begin
            ena   <= 1;
            enb   <= 0;
            wea   <= 1;
            addra <= count;
            addrb <= 0;
            dina  <= S_AXIS_TDATA;
            count <= count + 1;
            
            o_ena   <= 1;
            o_enb   <= 0;
            o_wea   <= 1;
            o_addra <= 0;
            o_addrb <= 0;
            o_dina  <= 0;
            
            p_count    <= 0;
            q_count    <= 0;
            bram_enb   <= 1;
            bram_addrb <= 0;
        end
        else if(state == PROCESS)begin
            ena   <= 0;
            enb   <= 1;
            wea   <= 0;
            addra <= 0;
            addrb <= q_count;
            dina  <= 0;
            count <= count;
            
            o_ena   <= 1;
            o_enb   <= 0;
            o_wea   <= 1;
            o_addra <= q_count - 1;   // dma bram read latency 고려 
            
            if(q_count < 10) begin
                o_dina  <= 100 + doutb;
                q_count <= q_count + 1;
            end else begin
                q_count <= q_count + 1;
                p_count <= p_count + 8;    //byte address
                o_dina  <= bram_doutb + 1000;
            end
            o_addrb <= 0;
//            o_dina  <= bram_doutb + doutb;
            
//            q_count    <= q_count + 1;
            bram_enb   <= 1;
            bram_addrb <= p_count;
        end
        else if(state == WAIT)begin
            ena   <= 0;
            enb   <= 0;
            wea   <= 0;
            addra <= 0;
            addrb <= 0;
            dina  <= 0;
            count <= count;
            
            o_ena   <= 0;
            o_enb   <= 1;
            o_wea   <= 0;
            o_addra <= 0;
            o_addrb <= 0;
            o_dina  <= 0;
            
            p_count    <= 0;
            q_count    <= 0;
            bram_enb   <= 0;
            bram_addrb <= 0;
        end
        else if(state == SEND)begin
            ena   <= 0;
            enb   <= 0;
            wea   <= 0;
            addra <= 0;
            addrb <= 0;
            dina  <= 0;
            count <= count - 1;
            
            o_ena   <= 0;
            o_enb   <= 1;
            o_wea   <= 0;
            o_addra <= 0;
            o_addrb <= p_count;
            o_dina  <= 0;
            
            p_count    <= p_count + 1;
            q_count    <= 0;
            bram_enb   <= 0;
            bram_addrb <= 0;
        end
    end
        
    
endmodule
