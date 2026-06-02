module ethMacParser (
    input wire clk,
    input wire rst,

    input wire [7:0] rawByte,
    input wire rawValid,
    output wire rawReady,

    output reg [7:0] payloadByte,
    output reg payloadValid,
    input wire payloadReady,

    output reg [15:0] etherType,
    output reg frameStart
);

    reg [3:0] byteCount;
    reg payloadState;
    reg [7:0] etherHigh;

    assign rawReady = 1'b1;

    reg rawValidPrev;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            byteCount    <= 0;
            payloadState <= 0;
            etherType    <= 0;
            etherHigh    <= 0;
            payloadByte  <= 0;
            payloadValid <= 0;
            frameStart   <= 0;
            rawValidPrev <= 0;
        end
        else begin
            payloadValid <= 0;
            frameStart   <= 0;
            rawValidPrev <= rawValid;

            if (rawValidPrev && !rawValid) begin
                payloadState <= 0;
                byteCount    <= 0;
            end

            if (rawValid) begin
                if (!payloadState) begin
                    if (byteCount == 12)
                        etherHigh <= rawByte;
                    if (byteCount == 13)
                        etherType <= {etherHigh, rawByte};
                    if (byteCount == 13) begin
                        payloadState <= 1;
                        byteCount    <= 0;
                        frameStart   <= 1;
                    end
                    else begin
                        byteCount <= byteCount + 1;
                    end
                end
                else begin
                    payloadByte  <= rawByte;
                    payloadValid <= 1;
                end
            end
        end
    end
endmodule

