module udpParser (
    input wire clk,
    input wire rst,

    input wire [7:0] inByte,
    input wire inValid,
    input wire headerStart,

    output wire inReady,

    output reg [7:0] outByte,
    output reg outValid,
    input wire outReady,

    output reg [15:0] sourcePort,
    output reg [15:0] destinationPort,
    output reg [15:0] udpLength,

    output reg payloadStart
);

    reg [3:0] byteCount;
    reg headerState;
    reg payloadState;
    reg [7:0] tempByte;
    reg firstPayload;

    assign inReady = 1'b1;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            byteCount       <= 0;
            headerState     <= 0;
            payloadState    <= 0;
            sourcePort      <= 0;
            destinationPort <= 0;
            udpLength       <= 0;
            tempByte        <= 0;
            outByte         <= 0;
            outValid        <= 0;
            payloadStart    <= 0;
            firstPayload    <= 0;
        end
        else begin
            outValid     <= 0;
            payloadStart <= 0;

            if (headerStart) begin
                headerState  <= 1;
                payloadState <= 0;
                byteCount    <= 0;
                firstPayload <= 1;
            end

            if (inValid) begin
                if (headerState) begin
                    case (byteCount)
                        4'd0: tempByte        <= inByte;
                        4'd1: sourcePort      <= {tempByte, inByte};
                        4'd2: tempByte        <= inByte;
                        4'd3: destinationPort <= {tempByte, inByte};
                        4'd4: tempByte        <= inByte;
                        4'd5: udpLength       <= {tempByte, inByte};
                        4'd7: begin
                            headerState  <= 0;
                            payloadState <= 1;
                            byteCount    <= 0;
                        end
                    endcase
                    if (byteCount != 4'd7)
                        byteCount <= byteCount + 1;
                end
                else if (payloadState) begin
                    outByte  <= inByte;
                    outValid <= 1;
                    if (firstPayload) begin
                        payloadStart <= 1;
                        firstPayload <= 0;
                    end
                end
            end
        end
    end
endmodule
