//TOP MODULE
module ALU(
    input Clk,
    input Rst,
    input [3:0] A,
    input [3:0] B,
    input [1:0] SL,
    output wire [6:0]dig,
    output wire [7:0]an,
    output wire dc 
  );
  reg [15:0]clkdiv;
  reg clkd;
  
  wire [3:0]q0,q1;
  wire [3:0]R,Q;
  wire [7:0]P;
  wire DC;
  wire [6:0] a,b,Q0,Q1,op1,op2;
  wire [6:0] op3;

   always@(posedge Clk, negedge Rst ) 
   begin 
   if(!Rst) 
   clkdiv<=0;
   else
   begin
   clkdiv <= clkdiv+1;   
   clkd <= clkdiv[15];
   end
   end
   
    mult muiltiplictn(Clk, Rst, 1'b1, 1'b1, 1'b1, A, B, P);    
    div divisn(Clk, Rst, 1'b1, 1'b1, 1'b1, A, B, R, Q); 
    oprtn oprtn_cntr(SL, A, B, P, R, Q, q0, q1, DC);
    
     seg seg7cnvrtA(A, a);
     seg seg7cnvrtB(B, b);
     seg seg7cnvrtQ0(q0, Q0);
     seg seg7cnvrtQ1(q1, Q1);
     
     sign sign1(SL, op1);
     sign0 sign2(SL, op2);
    assign op3 = 7'b1110110;
     
     segcntr seg7cntr(clkd,Rst,a,b,DC,Q0,Q1,op1,op2,op3, dig, dc, an);
   
   endmodule

//MULTIPLICATION
module mult(Clock, Resetn, s, LA, LB, DataA, DataB, P);

parameter n = 4;
input Clock, Resetn, LA, LB, s;
input [n-1:0] DataA, DataB;
output [n+n-1:0] P;
 reg Done;
wire z;
reg [n+n-1:0] DataP;
wire [n+n-1:0] A, Sum;
reg [1:0] y, Y;
wire [n-1:0] B;
reg EA, EB, EP, Psel;
integer k;

// control circuit
parameter S1 = 2'b00, S2 = 2'b01, S3 = 2'b10;

always @(s, y, z)
begin: State_table
case (y)
S1: if (s == 0) Y = S1;
else Y = S2;
S2: if (z == 0) Y = S2;
else Y = S3;
S3: if (s == 1) Y = S3;
else Y = S1;
default: Y = 2'bxx;
endcase
end

always @(posedge Clock, negedge Resetn)
begin: State_flipflops
if (Resetn == 0)
y <= S1;
else
y <=Y;
end

always @(s, y, B[0])
begin: FSM_outputs
// defaults
EA = 0; EB = 0; EP = 0; Done = 0; Psel = 0;

case (y)
S1: EP = 1;
S2: begin
EA= 1; EB = 1; Psel = 1;
if (B[0]) 
EP = 1;
else EP = 0;
end
S3: Done = 1;
endcase
end

//datapath circuit
shiftrne ShiftB (DataB, LB, EB, 1'b0, Clock, B);
defparam ShiftB.n = 4;

shiftlne ShiftA ({{n{1'b0}}, DataA}, LA, EA, 1'b0, Clock, A);
defparam ShiftA.n = 8;

assign z = (B == 0);
assign Sum = A + P;

// define the 2n 2-to-1 multiplexers
always @(Psel, Sum)
for (k = 0; k < n+n; k = k+1)
DataP[k] = Psel ? Sum[k] : 1'b0;

regne RegP (DataP, Clock, Resetn, EP, P);
defparam RegP.n = 8;

endmodule

//DIVISION
module div(Clock, Resetn, s, LA, EB, DataA, DataB, R, Q);

parameter n = 4, logn = 2;
input Clock, Resetn, s, LA, EB;
input [n-1:0] DataA, DataB;
output [n-1:0] R, Q;
 reg Done;
wire Cout, z, R0;
wire [n-1:0] DataR;
wire [n:0] Sum;
reg [1:0] y, Y;
wire [n-1:0] A, B;
wire [logn-1:0] Count;
reg EA, Rsel, LR, ER, ER0, LC, EC;
integer k;
// control circuit
parameter S1 = 2'b00, S2 = 2'b01, S3 = 2'b10;
always @(s, y, z)
begin: State_table
case (y)
S1: if (s == 0) Y = S1;
else Y = S2;
S2: if (z == 0) Y = S2;
else Y = S3;
S3: if (s == 1) Y = S3;
else Y = S1;
default: Y = 2'bxx;
endcase
end
always @(posedge Clock, negedge Resetn)
begin: State_flipflops
if (Resetn == 0)
y <= S1;
else
y <=Y;
end

always @(y, s, Cout, z)
begin: FSM_outputs
// defaults
LR = 0; ER = 0; ER0 = 0; LC = 0; EC = 0; EA= 0;
Rsel = 0; Done = 0;
case (y)
S1: begin
LC = 1; ER = 1;
if (s == 0)
begin
LR = 1; ER0 = 0;
end
else
begin
LR = 0; EA = 1; ER0 = 1;
end
end
S2: begin
Rsel = 1; ER = 1; ER0 = 1; EA= 1;
if (Cout) LR = 1;
else LR = 0;
if (z == 0) EC = 1;
else EC = 0;
end
S3: Done = 1;
endcase
end

regne RegB (DataB, Clock, Resetn, EB, B);
defparam RegB.n = n;

shiftlne ShiftR (DataR, LR, ER, R0, Clock, R);
defparam ShiftR.n = n;

muxdff FF_R0 (1'b0, A[n-1], ER0, Clock, R0);

shiftlne ShiftA (DataA, LA, EA, Cout, Clock, A);
defparam ShiftA.n = n;

assign Q =A;
downcount Counter (2'b11, Clock, EC, LC, Count);
defparam Counter.n = logn;

assign z = (Count == 0);
assign Sum = {1'b0, R[n-2:0], R0} + {1'b0, B} + 1;
assign Cout = Sum[n];

// define the n 2-to-1 multiplexers
assign DataR = Rsel ? Sum : 0;
endmodule

//OPERATION CONTROL
module oprtn(
    input [1:0]SL,
    input [3:0]a,
    input [3:0]b,
    input [7:0]p,
    input [3:0]r,
    input [3:0]q,
    output reg [3:0]q0,
    output reg [3:0]q1,
    output reg dc
    );
    
    
  always@(*)  
   case(SL)
   0 :  begin dc = 1;
          {q1,q0} = a + b;
          end
   1 :  begin dc = 1;
         {q1,q0} = p;
         end
   2 : begin dc = 0;
       q1 = q;
        q0 = r; 
        end
   3 : begin dc = 1;
        {q1,q0} = a - b;  
        end    
       endcase
   
endmodule

//HEXADECIMAL CONVERTOR
module seg(bcd,led);

input [3:0]bcd;
output reg [6:0]led;

  always@(bcd)
   case(bcd)
   0 : led=7'b0000001;
   1 : led=7'b1001111;
   2 : led=7'b0010010;
   3 : led=7'b0000110;
   4 : led=7'b1001100;
   5 : led=7'b0100100;
   6 : led=7'b0100000;
   7 : led=7'b0001111;
   8 : led=7'b0000000;
   9 : led=7'b0000100;
   10: led=7'b0001000;
   11: led=7'b1100000;
   12: led=7'b0110001;
   13: led=7'b1000010;
   14: led=7'b0110000;
   15: led=7'b0111000;
   
   endcase
endmodule

//PERTRN GENERATOR
module sign(
    input [1:0]SL,
    output reg [6:0]op
    );
    
    always@(*)
    case(SL)
    
    0 : op = 7'b1001110;
    2 : op = 7'b1111110;
    3 : op = 7'b1100111;
    1 : op = 7'b0000111;
    default op = 7'b1111111;
    endcase
endmodule

module sign0(
    input [1:0]SL,
    output reg [6:0]op
    );
    
    always@(*)
    case(SL)
    
    0 : op = 7'b1111110;
    3 : op = 7'b1111110;
    2 : op = 7'b0111101;
    1 : op = 7'b0110001;
    default op = 7'b1111111;
    endcase
endmodule

//INTASIATED MODULES
module shiftrne(R, L, E, w, Clock, Q);
parameter n = 4;
input [n-1:0] R;
input L, E, w, Clock;
output reg [n- 1:0] Q;
integer k;
always @(posedge Clock)
begin
if (L)
Q <= R;

else if (E)
begin
Q[n-1] <= w;

for (k = n-2; k >= 0; k = k-1)
Q[k] <= Q[k+ 1];
end
end
endmodule
module shiftlne(R, L, E, w, Clock, Q);
parameter n = 4;
input [n- 1:0] R;
input L, E, w, Clock;
output reg [n- 1:0] Q;
integer k;
always @(posedge Clock)
begin
if (L)
Q <= R;

else if (E)
begin

Q[0] <= w;

for (k =1 ; k >n-1 ; k = k+1)
Q[k+1] <= Q[k];
end
end

module regne(R, Clock, Resetn, E, Q);
parameter n = 8;
input [n-1:0] R;
input Clock, Resetn, E;
output reg [n-1:0] Q;
always @(posedge Clock, negedge Resetn)
if (Resetn == 0)
Q <= 0;
else if (E)
Q <= R;
endmodule

module muxdff(D0, D1, Sel, Clock, Q);
input D0, D1, Sel, Clock;
output reg Q;
wire D;
assign D = Sel ? D1 : D0;
always @(posedge Clock)
Q <= D;
endmodule
