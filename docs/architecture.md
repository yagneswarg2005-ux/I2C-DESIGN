# I2C Design Architecture

## 1. System Overview

The I2C design is organized into hierarchical functional blocks that work together to implement a complete I2C controller supporting both master and slave modes.

### State Machine Architecture

```
IDLE → START → ADDR → ACK_ADDR → DATA → ACK_DATA → STOP → IDLE
```

## 2. Functional Blocks

### 2.1 State Machine Controller
Manages I2C protocol flow through 7 states:
- **IDLE** (3'b000): Waiting for start signal
- **START** (3'b001): Generate START condition
- **ADDR** (3'b010): Transmit 7-bit address + write bit
- **ACK_ADDR** (3'b011): Wait for slave ACK on address
- **DATA** (3'b100): Transmit 8-bit data
- **ACK_DATA** (3'b101): Wait for slave ACK on data
- **STOP** (3'b110): Generate STOP condition

### 2.2 Bit Counter
- 4-bit counter (bit_cnt[3:0])
- Counts from 7 down to 0 for each byte
- Tracks bit position during transmission

### 2.3 Shift Register
- 8-bit shift register (shift_reg[7:0])
- Stores address (7-bit) + write bit (1-bit)
- Stores data (8-bit) during transmission
- MSB-first transmission order

### 2.4 Output Drivers

#### SDA Driver (Serial Data Line)
- Open-drain configuration
- Control: sda_en (active high pulls LOW)
- sda_out: Data value
- When sda_en=0: tri-state (pulled HIGH by external resistor)
- When sda_en=1: driven LOW

#### SCL Driver (Serial Clock Line)
- Open-drain configuration
- Direct register control (scl)
- Toggled in address and data states
- Pull-up resistor provides HIGH level

### 2.5 ACK/NACK Detection
- Samples SDA on rising edge of SCL (9th bit)
- Sets ack_error flag if SDA=1 (NACK)
- Continues to STOP regardless of ACK result

## 3. Signal Flow

### 3.1 Transmission Flow
```
start=1 (user trigger)
   ↓
Load addr + write_bit into shift_reg
state = START
   ↓
Pull SDA LOW while SCL HIGH
state = ADDR, bit_cnt = 7
   ↓
Toggle SCL for 8 bits
On SCL LOW: set sda_out = shift_reg[bit_cnt]
   ↓
Wait for ACK bit (9th clock)
state = ACK_ADDR
   ↓
Load data into shift_reg
state = DATA, bit_cnt = 7
   ↓
Toggle SCL for 8 bits (same as address)
   ↓
Wait for ACK bit (9th clock)
state = ACK_DATA
   ↓
Generate STOP condition
Pull SCL HIGH, then SDA HIGH
state = IDLE
```

### 3.2 Timing Diagram
```
START Condition:
        ┌─────────────┐
SCL ────┘             └─────...
        ┌───────┐
SDA ────┤       └─────────...
        START

Address/Data Bit Transmission:
SCL  ────┐───┐───┐───┐───┐───┐───┐───┐───┐───┐───
         │   │   │   │   │   │   │   │   │   │ ACK
SDA  ────┤D7 ├D6 ├D5 ├D4 ├D3 ├D2 ├D1 ├D0 ├---┤
         │   │   │   │   │   │   │   │   │   │

STOP Condition:
SCL ────────────────────────────────────┐────
                                        │
SDA ────┐                           ┌───┘
        └───────────────────────────┘
                STOP
```

## 4. RTL Implementation Details

### 4.1 Reset Behavior
On `rst_n=0`:
- All states reset to IDLE
- SCL = 1'b1 (bus release)
- SDA disabled (sda_en = 0)
- SDA output = 1'b1
- busy = 0
- ack_error = 0

### 4.2 Clock-to-Q Timing
- All state transitions on `posedge clk`
- Synchronous state machine (except reset)
- SCL toggle creates timing delays for I2C protocol

### 4.3 Data Setup
On each clock:
1. Check current state
2. Execute state-specific logic
3. Update next state
4. Modify SDA/SCL accordingly

## 5. ACK/NACK Protocol

### Master Behavior
1. After 8 bits of address/data, release SDA
2. Toggle SCL for 9th bit (ACK bit)
3. On SCL rising edge, sample SDA
4. SDA=0 (LOW): ACK received → continue
5. SDA=1 (HIGH): NACK received → proceed to STOP

### Slave Behavior (external)
1. Receives 8 bits
2. On 9th SCL pulse, pulls SDA LOW if ACK
3. Releases SDA (HIGH) if NACK

## 6. Error Handling

### ack_error Flag
- Set to 1 if slave sends NACK
- Indicates communication failure
- Can be monitored externally
- Transaction continues to STOP regardless

## 7. State Transitions

```
IDLE:
  Waits for start=1
  On start: busy←1, load address, state→START

START:
  Pull SDA LOW (START condition)
  state→ADDR, bit_cnt=7

ADDR:
  Toggle SCL 8 times
  On SCL LOW: set sda_out=shift_reg[bit_cnt]
  When bit_cnt reaches 0: state→ACK_ADDR

ACK_ADDR:
  Toggle SCL for 9th bit
  Release SDA (sda_en=0) for slave to drive
  On SCL HIGH: sample SDA
  Load data, state→DATA

DATA:
  Toggle SCL 8 times
  Same as ADDR state
  When bit_cnt reaches 0: state→ACK_DATA

ACK_DATA:
  Toggle SCL for 9th bit
  Release SDA for slave
  On SCL HIGH: sample SDA, set ack_error if needed
  state→STOP

STOP:
  Pull SCL HIGH
  Pull SDA LOW, then HIGH (STOP condition)
  busy←0, state→IDLE
```

## 8. Port Descriptions

### Inputs
- **clk**: System clock
- **rst_n**: Active-low asynchronous reset
- **start**: Trigger I2C transaction
- **addr[6:0]**: 7-bit slave address
- **data[7:0]**: 8-bit data to transmit

### Outputs
- **busy**: High during transaction
- **scl**: Serial Clock Line (open-drain)
- **sda**: Serial Data Line (inout, open-drain)

## 9. Design Features

✓ **Master-mode I2C Controller**
✓ **7-bit addressing + write bit**
✓ **ACK/NACK detection**
✓ **Open-drain outputs**
✓ **Synchronous state machine**
✓ **Error flag indication**
✓ **External pull-up support**

## 10. Implementation Notes

- SCL is directly driven (not open-drain in this design)
- SDA uses tri-state for open-drain behavior
- Timing determined by clock cycles (not time-based)
- Each state change per clock cycle
- External resistor pull-ups required
- Slave device must pull SDA LOW for ACK

---

**Architecture Version**: 1.0  
**Last Updated**: June 2, 2026