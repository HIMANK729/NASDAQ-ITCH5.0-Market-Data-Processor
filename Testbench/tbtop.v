
`timescale 1ns/1ps

module tbPipeline;

    reg clk, rst;

    initial clk = 0;
    always #2 clk = ~clk;   // 250 MHz

    reg  [7:0] rawByte;
    reg        rawValid;
    wire       rawReady;

    wire [31:0] bestBidPrice, bestBidShares;
    wire [31:0] bestAskPrice, bestAskShares;
    wire        bboValid;

    wire [31:0] lastLatencyNs, minLatencyNs, maxLatencyNs;
    wire [31:0] messageCount, bboUpdateCount, tradeCount;
    wire        statsValid;
    wire [6:0]  activeOrders;

    pipelineTop dut (
        .clk             (clk),
        .rst             (rst),
        .rawByte         (rawByte),
        .rawValid        (rawValid),
        .rawReady        (rawReady),
        .bestBidPrice    (bestBidPrice),
        .bestBidShares   (bestBidShares),
        .bestAskPrice    (bestAskPrice),
        .bestAskShares   (bestAskShares),
        .bboValid        (bboValid),
        .lastLatencyNs   (lastLatencyNs),
        .minLatencyNs    (minLatencyNs),
        .maxLatencyNs    (maxLatencyNs),
        .messageCount    (messageCount),
        .bboUpdateCount  (bboUpdateCount),
        .tradeCount      (tradeCount),
        .statsValid      (statsValid),
        .activeOrders    (activeOrders)
    );

    // Packet buffer
    reg [7:0] pkt [0:511];
    integer pktLen;

    // BBO logging
    integer bboNum;
    initial bboNum = 0;

    always @(posedge clk) begin
        if (bboValid && bestBidPrice != 0) begin
            bboNum = bboNum + 1;
            $display(
                "[BBO #%0d] t=%0t | Bid: %0d shares @ $%0d.%04d | Ask: %0d shares @ $%0d.%04d | Latency: %0d ns",
                bboNum, $time,
                bestBidShares, bestBidPrice/10000, bestBidPrice%10000,
                bestAskShares, bestAskPrice/10000, bestAskPrice%10000,
                lastLatencyNs
            );
        end
    end

    // Send packet task
    task sendPkt;
        integer idx;
        begin
            for (idx = 0; idx < pktLen; idx = idx + 1) begin
                @(posedge clk); #1;
                rawByte  = pkt[idx];
                rawValid = 1;
            end
            @(posedge clk); #1;
            rawValid = 0;
            rawByte  = 0;
            repeat (8) @(posedge clk);
        end
    endtask

    task buildHeaders;
        input [15:0] payloadLen;
        reg [15:0] ipTot, udpTot;
        integer h;
        begin
            ipTot  = 20 + 8 + payloadLen;
            udpTot = 8  + payloadLen;
            h = 0;

            // Ethernet (14 bytes)
            pkt[h]=8'hFF; h=h+1; pkt[h]=8'hFF; h=h+1; pkt[h]=8'hFF; h=h+1;
            pkt[h]=8'hFF; h=h+1; pkt[h]=8'hFF; h=h+1; pkt[h]=8'hFF; h=h+1;
            pkt[h]=8'h00; h=h+1; pkt[h]=8'h11; h=h+1; pkt[h]=8'h22; h=h+1;
            pkt[h]=8'h33; h=h+1; pkt[h]=8'h44; h=h+1; pkt[h]=8'h55; h=h+1;
            pkt[h]=8'h08; h=h+1; pkt[h]=8'h00; h=h+1;   // ethertype IPv4

            // IPv4 (20 bytes)
            pkt[h]=8'h45; h=h+1; pkt[h]=8'h00; h=h+1;
            pkt[h]=ipTot[15:8]; h=h+1; pkt[h]=ipTot[7:0]; h=h+1;
            pkt[h]=8'h00; h=h+1; pkt[h]=8'h01; h=h+1;
            pkt[h]=8'h00; h=h+1; pkt[h]=8'h00; h=h+1;
            pkt[h]=8'h40; h=h+1; pkt[h]=8'h11; h=h+1;   // TTL=64, proto=UDP
            pkt[h]=8'h00; h=h+1; pkt[h]=8'h00; h=h+1;   // checksum
            pkt[h]=8'hC0; h=h+1; pkt[h]=8'hA8; h=h+1;   // src 192.168.1.100
            pkt[h]=8'h01; h=h+1; pkt[h]=8'h64; h=h+1;
            pkt[h]=8'hEF; h=h+1; pkt[h]=8'h01; h=h+1;   // dst 239.1.1.1
            pkt[h]=8'h01; h=h+1; pkt[h]=8'h01; h=h+1;

            // UDP (8 bytes)
            pkt[h]=8'hC3; h=h+1; pkt[h]=8'h50; h=h+1;   // src port 50000
            pkt[h]=8'h26; h=h+1; pkt[h]=8'h48; h=h+1;   // dst port 9800
            pkt[h]=udpTot[15:8]; h=h+1; pkt[h]=udpTot[7:0]; h=h+1;
            pkt[h]=8'h00; h=h+1; pkt[h]=8'h00; h=h+1;   // checksum
        end
    endtask

  
    task sendAddOrder;
        input [63:0] orderRef;
        input [7:0]  side;
        input [31:0] shares;
        input [63:0] stock;
        input [31:0] price;
        integer b;
        begin
            buildHeaders(16'd36);   // 1 type byte + 35 body bytes
            b = 42;

            pkt[b]=8'h41; b=b+1;    // type 'A'

            // timestamp
            pkt[b]=8'h00; b=b+1; pkt[b]=8'h00; b=b+1; pkt[b]=8'h00; b=b+1;
            pkt[b]=8'h01; b=b+1; pkt[b]=8'hE8; b=b+1; pkt[b]=8'h48; b=b+1;

            // stock_locate
            pkt[b]=8'h00; b=b+1; pkt[b]=8'h01; b=b+1;

            // order_ref (8 bytes)
            pkt[b]=orderRef[63:56]; b=b+1; pkt[b]=orderRef[55:48]; b=b+1;
            pkt[b]=orderRef[47:40]; b=b+1; pkt[b]=orderRef[39:32]; b=b+1;
            pkt[b]=orderRef[31:24]; b=b+1; pkt[b]=orderRef[23:16]; b=b+1;
            pkt[b]=orderRef[15:8];  b=b+1; pkt[b]=orderRef[7:0];   b=b+1;

            // side
            pkt[b]=side; b=b+1;

            // shares
            pkt[b]=shares[31:24]; b=b+1; pkt[b]=shares[23:16]; b=b+1;
            pkt[b]=shares[15:8];  b=b+1; pkt[b]=shares[7:0];   b=b+1;

            // stock symbol
            pkt[b]=stock[63:56]; b=b+1; pkt[b]=stock[55:48]; b=b+1;
            pkt[b]=stock[47:40]; b=b+1; pkt[b]=stock[39:32]; b=b+1;
            pkt[b]=stock[31:24]; b=b+1; pkt[b]=stock[23:16]; b=b+1;
            pkt[b]=stock[15:8];  b=b+1; pkt[b]=stock[7:0];   b=b+1;

            // price
            pkt[b]=price[31:24]; b=b+1; pkt[b]=price[23:16]; b=b+1;
            pkt[b]=price[15:8];  b=b+1; pkt[b]=price[7:0];   b=b+1;

            // 2 padding bytes to reach 35 body bytes
            pkt[b]=8'h00; b=b+1; pkt[b]=8'h00; b=b+1;

            pktLen = b;
            sendPkt;
        end
    endtask

    task sendExecOrder;
        input [63:0] orderRef;
        input [31:0] shares;
        integer b;
        begin
            buildHeaders(16'd31);
            b = 42;

            pkt[b]=8'h45; b=b+1;   // 'E'
            pkt[b]=8'h00; b=b+1; pkt[b]=8'h00; b=b+1; pkt[b]=8'h00; b=b+1;
            pkt[b]=8'h02; b=b+1; pkt[b]=8'hD0; b=b+1; pkt[b]=8'h90; b=b+1;
            pkt[b]=8'h00; b=b+1; pkt[b]=8'h01; b=b+1;

            pkt[b]=orderRef[63:56]; b=b+1; pkt[b]=orderRef[55:48]; b=b+1;
            pkt[b]=orderRef[47:40]; b=b+1; pkt[b]=orderRef[39:32]; b=b+1;
            pkt[b]=orderRef[31:24]; b=b+1; pkt[b]=orderRef[23:16]; b=b+1;
            pkt[b]=orderRef[15:8];  b=b+1; pkt[b]=orderRef[7:0];   b=b+1;

            pkt[b]=shares[31:24]; b=b+1; pkt[b]=shares[23:16]; b=b+1;
            pkt[b]=shares[15:8];  b=b+1; pkt[b]=shares[7:0];   b=b+1;

            // match number (8 bytes)
            pkt[b]=8'h00; b=b+1; pkt[b]=8'h00; b=b+1; pkt[b]=8'h00; b=b+1;
            pkt[b]=8'h00; b=b+1; pkt[b]=8'h00; b=b+1; pkt[b]=8'h00; b=b+1;
            pkt[b]=8'h00; b=b+1; pkt[b]=8'h01; b=b+1;

            pktLen = b;
            sendPkt;
        end
    endtask

    task sendCancelOrder;
        input [63:0] orderRef;
        input [31:0] shares;
        integer b;
        begin
            buildHeaders(16'd22);
            b = 42;

            pkt[b]=8'h58; b=b+1;  // 'X'
            pkt[b]=8'h00; b=b+1; pkt[b]=8'h00; b=b+1; pkt[b]=8'h00; b=b+1;
            pkt[b]=8'h03; b=b+1; pkt[b]=8'hB9; b=b+1; pkt[b]=8'hC0; b=b+1;
            pkt[b]=8'h00; b=b+1; pkt[b]=8'h01; b=b+1;

            pkt[b]=orderRef[63:56]; b=b+1; pkt[b]=orderRef[55:48]; b=b+1;
            pkt[b]=orderRef[47:40]; b=b+1; pkt[b]=orderRef[39:32]; b=b+1;
            pkt[b]=orderRef[31:24]; b=b+1; pkt[b]=orderRef[23:16]; b=b+1;
            pkt[b]=orderRef[15:8];  b=b+1; pkt[b]=orderRef[7:0];   b=b+1;

            pkt[b]=shares[31:24]; b=b+1; pkt[b]=shares[23:16]; b=b+1;
            pkt[b]=shares[15:8];  b=b+1; pkt[b]=shares[7:0];   b=b+1;

            pktLen = b;
            sendPkt;
        end
    endtask

    
    localparam [63:0] AAPL = 64'h4141504C20202020;

    initial begin
        $dumpfile("sim/wave.vcd");
        $dumpvars(0, tbPipeline);

        rst = 1;
        rawValid = 0;
        rawByte = 0;

        repeat (10) @(posedge clk);
        rst = 0;
        repeat (5) @(posedge clk);

        $display("\n========================================");
        $display(" NASDAQ ITCH 5.0 Pipeline Simulation");
        $display(" 250 MHz clock  |  AAPL Order Book");
        $display("========================================\n");

        // ---- Buy orders ----
        $display("[+] Add Buy  100 @ $182.50");
        sendAddOrder(64'h01, 8'h42, 100, AAPL, 32'd1825000);

        $display("[+] Add Buy  200 @ $182.40");
        sendAddOrder(64'h02, 8'h42, 200, AAPL, 32'd1824000);

        $display("[+] Add Buy  150 @ $182.60  <- should be new best bid");
        sendAddOrder(64'h03, 8'h42, 150, AAPL, 32'd1826000);

        // ---- Sell orders ----
        $display("[+] Add Sell 100 @ $183.00");
        sendAddOrder(64'h10, 8'h53, 100, AAPL, 32'd1830000);

        $display("[+] Add Sell 250 @ $182.80");
        sendAddOrder(64'h11, 8'h53, 250, AAPL, 32'd1828000);

        $display("[+] Add Sell  50 @ $182.70  <- should be new best ask");
        sendAddOrder(64'h12, 8'h53, 50, AAPL, 32'd1827000);

        repeat (20) @(posedge clk);
        $display("\n[INFO] Active orders: %0d", activeOrders);
        $display(
            "[INFO] BBO → Bid %0d@$%0d.%04d | Ask %0d@$%0d.%04d\n",
            bestBidShares, bestBidPrice/10000, bestBidPrice%10000,
            bestAskShares, bestAskPrice/10000, bestAskPrice%10000
        );

        // ---- Execute partial ask ----
        $display("[E] Execute 20 shares of ask order ref=0x12");
        sendExecOrder(64'h12, 20);

        // ---- Cancel partial bid ----
        $display("[X] Cancel 50 shares of bid order ref=0x03");
        sendCancelOrder(64'h03, 50);

        // ---- Tighter spread ----
        $display("[+] Add Buy  300 @ $182.65  <- new best bid");
        sendAddOrder(64'h20, 8'h42, 300, AAPL, 32'd1826500);

        $display("[+] Add Sell 200 @ $182.68  <- tight spread");
        sendAddOrder(64'h21, 8'h53, 200, AAPL, 32'd1826800);

        repeat (30) @(posedge clk);

        $display("\n========================================");
        $display("  FINAL PERFORMANCE STATISTICS");
        $display("========================================");
        $display("  Messages processed  : %0d", messageCount);
        $display("  BBO updates         : %0d", bboUpdateCount);
        $display("  Trade messages      : %0d", tradeCount);
        $display("  Active orders       : %0d", activeOrders);
        $display("  Latency MIN         : %0d ns", minLatencyNs);
        $display("  Latency MAX         : %0d ns", maxLatencyNs);
        $display("  Latency LAST        : %0d ns", lastLatencyNs);
        $display(
            "  Final Best Bid      : %0d shares @ $%0d.%04d",
            bestBidShares, bestBidPrice/10000, bestBidPrice%10000
        );
        $display(
            "  Final Best Ask      : %0d shares @ $%0d.%04d",
            bestAskShares, bestAskPrice/10000, bestAskPrice%10000
        );
        $display(
            "  Spread              : $%0d.%04d",
            (bestAskPrice - bestBidPrice)/10000,
            (bestAskPrice - bestBidPrice)%10000
        );
        $display("========================================\n");

        $finish;
    end

    initial begin
        #2000000;
        $display("WATCHDOG: timeout");
        $finish;
    end

endmodule
