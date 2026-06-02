module pipelineTop (
    input wire clk,
    input wire rst,

    input wire [7:0] rawByte,
    input wire rawValid,
    output wire rawReady,

    output wire [31:0] bestBidPrice,
    output wire [31:0] bestBidShares,
    output wire [31:0] bestAskPrice,
    output wire [31:0] bestAskShares,
    output wire bboValid,

    output wire [31:0] lastLatencyNs,
    output wire [31:0] minLatencyNs,
    output wire [31:0] maxLatencyNs,
    output wire [31:0] messageCount,
    output wire [31:0] bboUpdateCount,
    output wire [31:0] tradeCount,
    output wire statsValid,
    output wire [6:0] activeOrders
);

    wire [7:0]  ethOutByte;
    wire        ethOutValid;
    wire        ethOutReady;
    wire [15:0] etherType;
    wire        ethFrameStart;

    wire [7:0] ipv4OutByte;
    wire       ipv4OutValid;
    wire       ipv4OutReady;
    wire       ipv4HeaderDone;

    wire [7:0] udpOutByte;
    wire       udpOutValid;
    wire       udpPayloadStart;

    wire        addOrderValid;
    wire [63:0] addOrderRef;
    wire [7:0]  addOrderSide;
    wire [31:0] addOrderShares;
    wire [63:0] addOrderStock;
    wire [31:0] addOrderPrice;

    wire        execOrderValid;
    wire [63:0] execOrderRef;
    wire [31:0] execShares;

    wire        cancelValid;
    wire [63:0] cancelRef;
    wire [31:0] cancelShares;

    wire        deleteValid;
    wire [63:0] deleteRef;

    wire        tradeValid;
    wire [31:0] tradePrice;

    ethMacParser ethernetParser (
        .clk(clk), .rst(rst),
        .rawByte(rawByte), .rawValid(rawValid), .rawReady(rawReady),
        .payloadByte(ethOutByte), .payloadValid(ethOutValid), .payloadReady(ethOutReady),
        .etherType(etherType), .frameStart(ethFrameStart)
    );

    ipv4Parser ipParser (
        .clk(clk), .rst(rst),
        .inByte(ethOutByte), .inValid(ethOutValid), .inFrameStart(ethFrameStart),
        .inReady(ethOutReady),
        .outByte(ipv4OutByte), .outValid(ipv4OutValid), .outReady(ipv4OutReady),
        .headerDone(ipv4HeaderDone)
    );

    udpParser udpPacketParser (
        .clk(clk), .rst(rst),
        .inByte(ipv4OutByte), .inValid(ipv4OutValid),
        .headerStart(ipv4HeaderDone),
        .inReady(ipv4OutReady),
        .outByte(udpOutByte), .outValid(udpOutValid),
        .outReady(1'b1),
        .payloadStart(udpPayloadStart)
    );

    itchDecoder itchMessageDecoder (
        .clk(clk), .rst(rst),
        .inByte(udpOutByte), .inValid(udpOutValid),
        .inReady(),
        .addOrderValid(addOrderValid), .addOrderRef(addOrderRef),
        .addOrderSide(addOrderSide), .addOrderShares(addOrderShares),
        .addOrderStock(addOrderStock), .addOrderPrice(addOrderPrice),
        .execOrderValid(execOrderValid), .execOrderRef(execOrderRef), .execShares(execShares),
        .cancelValid(cancelValid), .cancelRef(cancelRef), .cancelShares(cancelShares),
        .deleteValid(deleteValid), .deleteRef(deleteRef),
        .tradeValid(tradeValid), .tradeOrderRef(), .tradeShares(),
        .tradeStock(), .tradePrice(tradePrice),
        .msgTimestamp()
    );

    orderBook #(.maxOrders(64)) bookEngine (
        .clk(clk), .rst(rst),
        .addValid(addOrderValid), .addRef(addOrderRef),
        .addSide(addOrderSide), .addShares(addOrderShares), .addPrice(addOrderPrice),
        .execValid(execOrderValid), .execRef(execOrderRef), .execShares(execShares),
        .cancelValid(cancelValid), .cancelRef(cancelRef), .cancelShares(cancelShares),
        .deleteValid(deleteValid), .deleteRef(deleteRef),
        .bestBidPrice(bestBidPrice), .bestBidShares(bestBidShares),
        .bestAskPrice(bestAskPrice), .bestAskShares(bestAskShares),
        .bboValid(bboValid), .activeOrders(activeOrders)
    );

    latencyStats #(.clockPeriodNs(4)) statsModule (
        .clk(clk), .rst(rst),
        .msgStart(udpPayloadStart), .bboUpdate(bboValid), .tradeEvent(tradeValid),
        .lastLatencyNs(lastLatencyNs), .minLatencyNs(minLatencyNs), .maxLatencyNs(maxLatencyNs),
        .totalLatencyNs(),
        .messageCount(messageCount), .bboUpdateCount(bboUpdateCount), .tradeCount(tradeCount),
        .statsValid(statsValid)
    );

endmodule
