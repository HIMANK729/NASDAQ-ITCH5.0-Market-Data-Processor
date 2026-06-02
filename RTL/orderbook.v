module orderBook #(
    parameter maxOrders = 64
)(
    input wire clk,
    input wire rst,

    input wire addValid,
    input wire [63:0] addRef,
    input wire [7:0] addSide,
    input wire [31:0] addShares,
    input wire [31:0] addPrice,

    input wire execValid,
    input wire [63:0] execRef,
    input wire [31:0] execShares,

    input wire cancelValid,
    input wire [63:0] cancelRef,
    input wire [31:0] cancelShares,

    input wire deleteValid,
    input wire [63:0] deleteRef,

    output reg [31:0] bestBidPrice,
    output reg [31:0] bestBidShares,
    output reg [31:0] bestAskPrice,
    output reg [31:0] bestAskShares,
    output reg bboValid,

    output reg [6:0] activeOrders
);

    reg [63:0] orderRef    [0:maxOrders-1];
    reg [31:0] orderPrice  [0:maxOrders-1];
    reg [31:0] orderShares [0:maxOrders-1];
    reg [7:0]  orderSide   [0:maxOrders-1];
    reg        orderValid  [0:maxOrders-1];

    integer i, j;

    // Free slot finder
    reg [5:0] freeIndex;
    reg       freeAvailable;

    always @(*) begin
        freeIndex     = 0;
        freeAvailable = 0;
        for (i = 0; i < maxOrders; i = i + 1) begin
            if (!orderValid[i] && !freeAvailable) begin
                freeIndex     = i[5:0];
                freeAvailable = 1;
            end
        end
    end

    wire [63:0] searchRef = execValid   ? execRef   :
                            cancelValid ? cancelRef :
                            deleteValid ? deleteRef : 64'd0;

    // Order lookup
    reg [5:0] matchedIndex;
    reg       matchFound;

    always @(*) begin
        matchedIndex = 0;
        matchFound   = 0;
        for (i = 0; i < maxOrders; i = i + 1) begin
            if (orderValid[i] && (orderRef[i] == searchRef) && !matchFound) begin
                matchedIndex = i[5:0];
                matchFound   = 1;
            end
        end
    end

    // Best Bid / Ask combinational logic
    reg [31:0] bidPrice;
    reg [31:0] bidShares;
    reg [31:0] askPrice;
    reg [31:0] askShares;
    reg        haveBid;
    reg        haveAsk;

    always @(*) begin
        bidPrice  = 0;
        bidShares = 0;
        haveBid   = 0;
        askPrice  = 32'hFFFFFFFF;
        askShares = 0;
        haveAsk   = 0;

        for (i = 0; i < maxOrders; i = i + 1) begin
            if (orderValid[i]) begin
                if (orderSide[i] == 8'h42) begin
                    if (!haveBid || orderPrice[i] > bidPrice) begin
                        bidPrice  = orderPrice[i];
                        bidShares = orderShares[i];
                        haveBid   = 1;
                    end
                    else if (orderPrice[i] == bidPrice) begin
                        bidShares = bidShares + orderShares[i];
                    end
                end
                else begin
                    if (!haveAsk || orderPrice[i] < askPrice) begin
                        askPrice  = orderPrice[i];
                        askShares = orderShares[i];
                        haveAsk   = 1;
                    end
                    else if (orderPrice[i] == askPrice) begin
                        askShares = askShares + orderShares[i];
                    end
                end
            end
        end

        if (!haveAsk) askPrice = 0;
    end

    
    reg [6:0] orderCount;
    always @(*) begin
        orderCount = 0;
        for (j = 0; j < maxOrders; j = j + 1)
            if (orderValid[j])
                orderCount = orderCount + 1;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < maxOrders; i = i + 1) begin
                orderValid[i]  <= 0;
                orderRef[i]    <= 0;
                orderPrice[i]  <= 0;
                orderShares[i] <= 0;
                orderSide[i]   <= 0;
            end
            bestBidPrice  <= 0;
            bestBidShares <= 0;
            bestAskPrice  <= 0;
            bestAskShares <= 0;
            bboValid      <= 0;
            activeOrders  <= 0;
        end
        else begin
            bboValid <= 0;

            if (addValid && freeAvailable) begin
                orderRef[freeIndex]    <= addRef;
                orderPrice[freeIndex]  <= addPrice;
                orderShares[freeIndex] <= addShares;
                orderSide[freeIndex]   <= addSide;
                orderValid[freeIndex]  <= 1;
            end

            if (execValid && matchFound) begin
                if (orderShares[matchedIndex] <= execShares)
                    orderValid[matchedIndex] <= 0;
                else
                    orderShares[matchedIndex] <= orderShares[matchedIndex] - execShares;
            end

            if (cancelValid && matchFound) begin
                if (orderShares[matchedIndex] <= cancelShares)
                    orderValid[matchedIndex] <= 0;
                else
                    orderShares[matchedIndex] <= orderShares[matchedIndex] - cancelShares;
            end

            if (deleteValid && matchFound)
                orderValid[matchedIndex] <= 0;

            
            if ((bidPrice  != bestBidPrice  ||
                 bidShares != bestBidShares ||
                 askPrice  != bestAskPrice  ||
                 askShares != bestAskShares) &&
                (haveBid || haveAsk)) begin

                bestBidPrice  <= bidPrice;
                bestBidShares <= bidShares;
                bestAskPrice  <= askPrice;
                bestAskShares <= askShares;
                bboValid      <= 1;
            end

            activeOrders <= orderCount;
        end
    end
endmodule
