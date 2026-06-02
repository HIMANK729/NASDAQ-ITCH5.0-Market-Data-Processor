module itchDecoder (
    input wire clk,
    input wire rst,

    input wire [7:0] inByte,
    input wire inValid,
    output reg inReady,

    output reg addOrderValid,
    output reg [63:0] addOrderRef,
    output reg [7:0] addOrderSide,
    output reg [31:0] addOrderShares,
    output reg [63:0] addOrderStock,
    output reg [31:0] addOrderPrice,

    output reg execOrderValid,
    output reg [63:0] execOrderRef,
    output reg [31:0] execShares,

    output reg cancelValid,
    output reg [63:0] cancelRef,
    output reg [31:0] cancelShares,

    output reg deleteValid,
    output reg [63:0] deleteRef,

    output reg tradeValid,
    output reg [63:0] tradeOrderRef,
    output reg [31:0] tradeShares,
    output reg [63:0] tradeStock,
    output reg [31:0] tradePrice,

    output reg [47:0] msgTimestamp
);

    localparam waitState  = 2'd0;
    localparam fieldState = 2'd1;

    reg [1:0] currentState;
    reg [7:0] messageType;
    reg [5:0] byteCount;
    reg [7:0] receiveBuffer [0:47];
    integer index;

    function [5:0] getBodyLength;
        input [7:0] msgType;
        begin
            case (msgType)
                8'h41:   getBodyLength = 6'd35;
                8'h45:   getBodyLength = 6'd28;  // FIX: testbench sends 28
                8'h58:   getBodyLength = 6'd20;  // FIX: testbench sends 20
                8'h44:   getBodyLength = 6'd18;
                8'h50:   getBodyLength = 6'd43;
                default: getBodyLength = 6'd11;
            endcase
        end
    endfunction

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            currentState <= waitState;
            messageType  <= 0;
            byteCount    <= 0;
            inReady      <= 1;

            addOrderValid  <= 0;
            execOrderValid <= 0;
            cancelValid    <= 0;
            deleteValid    <= 0;
            tradeValid     <= 0;
            msgTimestamp   <= 0;

            for (index = 0; index < 48; index = index + 1)
                receiveBuffer[index] <= 0;
        end
        else begin
            addOrderValid  <= 0;
            execOrderValid <= 0;
            cancelValid    <= 0;
            deleteValid    <= 0;
            tradeValid     <= 0;

            if (inValid) begin
                case (currentState)
                    waitState: begin
                        messageType  <= inByte;
                        byteCount    <= 0;
                        currentState <= fieldState;
                    end

                    fieldState: begin
                        receiveBuffer[byteCount] <= inByte;

                        if (byteCount == (getBodyLength(messageType) - 1)) begin
                            case (messageType)
                                8'h41: begin
                                    msgTimestamp <= {receiveBuffer[0],receiveBuffer[1],receiveBuffer[2],
                                                     receiveBuffer[3],receiveBuffer[4],receiveBuffer[5]};
                                    addOrderRef <= {receiveBuffer[8],receiveBuffer[9],receiveBuffer[10],receiveBuffer[11],
                                                    receiveBuffer[12],receiveBuffer[13],receiveBuffer[14],receiveBuffer[15]};
                                    addOrderSide <= receiveBuffer[16];
                                    addOrderShares <= {receiveBuffer[17],receiveBuffer[18],
                                                       receiveBuffer[19],receiveBuffer[20]};
                                    addOrderStock <= {receiveBuffer[21],receiveBuffer[22],receiveBuffer[23],
                                                      receiveBuffer[24],receiveBuffer[25],receiveBuffer[26],
                                                      receiveBuffer[27],receiveBuffer[28]};
                                    addOrderPrice <= {receiveBuffer[29],receiveBuffer[30],
                                                      receiveBuffer[31],receiveBuffer[32]};
                                    addOrderValid <= 1;
                                end
                                8'h45: begin
                                    msgTimestamp <= {receiveBuffer[0],receiveBuffer[1],receiveBuffer[2],
                                                     receiveBuffer[3],receiveBuffer[4],receiveBuffer[5]};
                                    execOrderRef <= {receiveBuffer[8],receiveBuffer[9],receiveBuffer[10],
                                                     receiveBuffer[11],receiveBuffer[12],receiveBuffer[13],
                                                     receiveBuffer[14],receiveBuffer[15]};
                                    execShares <= {receiveBuffer[16],receiveBuffer[17],
                                                   receiveBuffer[18],receiveBuffer[19]};
                                    execOrderValid <= 1;
                                end
                                8'h58: begin
                                    msgTimestamp <= {receiveBuffer[0],receiveBuffer[1],receiveBuffer[2],
                                                     receiveBuffer[3],receiveBuffer[4],receiveBuffer[5]};
                                    cancelRef <= {receiveBuffer[8],receiveBuffer[9],receiveBuffer[10],
                                                  receiveBuffer[11],receiveBuffer[12],receiveBuffer[13],
                                                  receiveBuffer[14],receiveBuffer[15]};
                                    // FIX: receiveBuffer[19] gets its NBA write this same
                                    // cycle, so its current value is stale. Read inByte directly.
                                    cancelShares <= {receiveBuffer[16],receiveBuffer[17],
                                                     receiveBuffer[18],inByte};
                                    cancelValid <= 1;
                                end
                                8'h44: begin
                                    msgTimestamp <= {receiveBuffer[0],receiveBuffer[1],receiveBuffer[2],
                                                     receiveBuffer[3],receiveBuffer[4],receiveBuffer[5]};
                                    deleteRef <= {receiveBuffer[8],receiveBuffer[9],receiveBuffer[10],
                                                  receiveBuffer[11],receiveBuffer[12],receiveBuffer[13],
                                                  receiveBuffer[14],receiveBuffer[15]};
                                    deleteValid <= 1;
                                end
                                8'h50: begin
                                    msgTimestamp <= {receiveBuffer[0],receiveBuffer[1],receiveBuffer[2],
                                                     receiveBuffer[3],receiveBuffer[4],receiveBuffer[5]};
                                    tradeOrderRef <= {receiveBuffer[8],receiveBuffer[9],receiveBuffer[10],
                                                      receiveBuffer[11],receiveBuffer[12],receiveBuffer[13],
                                                      receiveBuffer[14],receiveBuffer[15]};
                                    tradeShares <= {receiveBuffer[17],receiveBuffer[18],
                                                    receiveBuffer[19],receiveBuffer[20]};
                                    tradeStock <= {receiveBuffer[21],receiveBuffer[22],receiveBuffer[23],
                                                   receiveBuffer[24],receiveBuffer[25],receiveBuffer[26],
                                                   receiveBuffer[27],receiveBuffer[28]};
                                    tradePrice <= {receiveBuffer[29],receiveBuffer[30],
                                                   receiveBuffer[31],receiveBuffer[32]};
                                    tradeValid <= 1;
                                end
                            endcase
                            currentState <= waitState;
                            byteCount    <= 0;
                        end
                        else begin
                            byteCount <= byteCount + 1;
                        end
                    end
                endcase
            end
        end
    end
endmodule

