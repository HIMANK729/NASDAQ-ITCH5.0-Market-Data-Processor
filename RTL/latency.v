module latencyStats #(
    parameter clockPeriodNs = 4
)(
    input wire clk,
    input wire rst,

    input wire msgStart,
    input wire bboUpdate,
    input wire tradeEvent,

    output reg [31:0] lastLatencyNs,
    output reg [31:0] minLatencyNs,
    output reg [31:0] maxLatencyNs,
    output reg [63:0] totalLatencyNs,

    output reg [31:0] messageCount,
    output reg [31:0] bboUpdateCount,
    output reg [31:0] tradeCount,

    output reg statsValid
);

    reg [31:0] cycleCounter;
    reg measuringState;
    reg [31:0] latencyValue;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cycleCounter   <= 0;
            measuringState <= 0;
            latencyValue   <= 0;
            lastLatencyNs  <= 0;
            minLatencyNs   <= 32'hFFFF_FFFF;
            maxLatencyNs   <= 0;
            totalLatencyNs <= 0;
            messageCount   <= 0;
            bboUpdateCount <= 0;
            tradeCount     <= 0;
            statsValid     <= 0;
        end
        else begin
            statsValid <= 0;

            if (msgStart) begin
                cycleCounter   <= 0;
                measuringState <= 1;
                messageCount   <= messageCount + 1;
            end

            if (measuringState)
                cycleCounter <= cycleCounter + 1;

            if (bboUpdate && measuringState) begin
                latencyValue = cycleCounter * clockPeriodNs;
                lastLatencyNs  <= latencyValue;
                totalLatencyNs <= totalLatencyNs + latencyValue;
                bboUpdateCount <= bboUpdateCount + 1;
                statsValid <= 1;
                measuringState <= 0;
                cycleCounter   <= 0;
                if (latencyValue < minLatencyNs)
                    minLatencyNs <= latencyValue;
                if (latencyValue > maxLatencyNs)
                    maxLatencyNs <= latencyValue;
            end

            if (tradeEvent)
                tradeCount <= tradeCount + 1;
        end
    end
endmodule
