# NASDAQ ITCH 5.0 Market Data Processing Pipeline

## Overview

This project implements a hardware-accelerated NASDAQ ITCH 5.0 market data processing pipeline in Verilog. The design receives raw Ethernet packets, parses network protocols, decodes NASDAQ ITCH messages, reconstructs a real-time order book, generates Best Bid and Offer (BBO) updates, and measures end-to-end processing latency.

The system is designed as a fully streaming FPGA-friendly architecture suitable for High-Frequency Trading (HFT), market data feed handling, and low-latency financial applications.

---

## Architecture

<img width="1024" height="559" alt="image" src="https://github.com/user-attachments/assets/0798a3bd-cad1-4f7c-88f8-84749ea9cd8e" />

---

# Features

## Network Protocol Support

* Ethernet Frame Parsing
* IPv4 Packet Parsing
* UDP Packet Parsing
* Streaming Packet Processing
* Hardware-Friendly Pipeline Architecture

## NASDAQ ITCH 5.0 Support

The decoder currently supports:

| Message Type | Description    |
| ------------ | -------------- |
| A            | Add Order      |
| E            | Order Executed |
| X            | Order Cancel   |
| D            | Order Delete   |
| P            | Trade Message  |

---

# Order Book Engine

The order book maintains active orders and continuously updates market state.

Supported operations:

### Add Order

Creates a new order entry containing:

* Order Reference Number
* Side (Buy/Sell)
* Quantity
* Price
* Stock Symbol

### Execute Order

Reduces order quantity based on executed shares.

### Cancel Order

Reduces order quantity based on canceled shares.

### Delete Order

Removes an order completely.

### BBO Calculation

The engine continuously computes:

```text
Best Bid  = Highest Buy Price
Best Ask  = Lowest Sell Price
Spread    = Best Ask - Best Bid
```

---

# Hardware Modules

## 1. Ethernet MAC Parser

### Functionality

* Parses Ethernet headers
* Extracts EtherType
* Detects frame boundaries
* Forwards payload to IPv4 parser

### Outputs

```verilog
payloadByte
payloadValid
etherType
frameStart
```

---

## 2. IPv4 Parser

### Functionality

Extracts:

* Source IP Address
* Destination IP Address
* Protocol Field
* Total Length

Generates a header completion signal when IPv4 parsing is complete.

### Outputs

```verilog
srcIp
dstIp
protocol
totalLength
headerDone
```

---

## 3. UDP Parser

### Functionality

Extracts:

* Source Port
* Destination Port
* UDP Length

Removes UDP headers and forwards ITCH payload bytes.

### Outputs

```verilog
sourcePort
destinationPort
udpLength
payloadStart
```

---

## 4. NASDAQ ITCH Decoder

### Functionality

Converts incoming byte streams into structured market events.

### Decoded Information

#### Add Order

```text
Order Reference
Buy/Sell Side
Shares
Stock Symbol
Price
```

#### Execute Order

```text
Order Reference
Executed Shares
```

#### Cancel Order

```text
Order Reference
Canceled Shares
```

#### Delete Order

```text
Order Reference
```

#### Trade Message

```text
Trade Price
Trade Quantity
Trade Stock
```

---

## 5. Order Book

### Capacity

```text
64 Active Orders
```

### Internal Storage

Each order stores:

```text
Order Reference Number
Price
Quantity
Side
Valid Bit
```

### Supported Functions

* Add Order
* Execute Order
* Cancel Order
* Delete Order
* Best Bid Calculation
* Best Ask Calculation
* Active Order Tracking

---

## 6. Latency Statistics Module

The latency engine measures the processing delay between:

```text
Incoming Message
        ↓
BBO Update Generation
```

### Metrics Collected

* Message Count
* BBO Update Count
* Trade Count
* Minimum Latency
* Maximum Latency
* Last Observed Latency
* Total Latency

### Clock Configuration

```text
Frequency : 250 MHz
Period    : 4 ns
```

---

# Simulation Scenario

The testbench simulates an AAPL order book.

## Buy Orders

```text
100 shares @ $182.50
200 shares @ $182.40
150 shares @ $182.60
```

## Sell Orders

```text
100 shares @ $183.00
250 shares @ $182.80
50 shares  @ $182.70
```

### Initial BBO

```text
Best Bid : 150 @ $182.60
Best Ask : 50  @ $182.70
Spread   : $0.10
```

---

# Order Book Updates

## Execute Order

```text
Execute 20 shares of Ask Order
```

Result:

```text
50 shares → 30 shares
```

---

## Cancel Order

```text
Cancel 50 shares of Bid Order
```

Result:

```text
150 shares → 100 shares
```

---

## New Best Bid

```text
300 shares @ $182.65
```

---

## New Best Ask

```text
200 shares @ $182.68
```

---

# Final Simulation Results

```text
Messages Processed : 10

BBO Updates        : 9

Trade Messages     : 0

Active Orders      : 8

Latency MIN        : 88 ns

Latency MAX        : 496 ns

Latency LAST       : 148 ns

Final Best Bid     : 300 shares @ $182.6500

Final Best Ask     : 200 shares @ $182.6800

Spread             : $0.0300
```

---

# Performance Analysis

| Metric             | Value   |
| ------------------ | ------- |
| Clock Frequency    | 250 MHz |
| Clock Period       | 4 ns    |
| Minimum Latency    | 88 ns   |
| Maximum Latency    | 496 ns  |
| Typical Latency    | ~148 ns |
| Messages Processed | 10      |
| BBO Updates        | 9       |

The design demonstrates sub-microsecond processing latency suitable for low-latency trading systems.

---

# Verification Methodology

The testbench validates:

### Functional Verification

* Add Orders
* Execute Orders
* Cancel Orders
* Delete Orders
* Trade Messages

### Order Book Verification

* Best Bid Updates
* Best Ask Updates
* Spread Calculation
* Active Order Tracking


---

# Applications

* High-Frequency Trading (HFT)
* FPGA Market Data Feed Handlers
* Financial Hardware Acceleration
* Exchange Connectivity Research
* Low-Latency Networking
* FPGA-Based Trading Infrastructure

---

# Future Enhancements

## Market Data

* Full NASDAQ ITCH 5.0 Coverage
* Multi-Symbol Support
* Multi-Book Support

## FPGA Optimization

* BRAM-Based Order Storage
* Pipelined Search Engine
* Parallel Order Lookup
* Multi-Level Order Book


