library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use STD.TEXTIO.all;
USE work.fpm_test_vect.all;
entity fpm is
  PORT (A,B : IN std_logic_vector (31 downto 0);
        latch, drive: IN std_ulogic;
        C : OUT std_logic_vector (31 downto 0));
end fpm;

architecture behavioral of fpm is
signal A_in, B_in : std_logic_vector (31 downto 0);
signal final_result : std_logic_vector (31 downto 0);
constant NaN:  STD_LOGIC_VECTOR(31 downto 0) := "01111111100000000000000000000001";
constant pos_inf: STD_LOGIC_VECTOR(31 downto 0) := "01111111100000000000000000000000";
constant neg_inf: STD_LOGIC_VECTOR(31 downto 0) := "11111111100000000000000000000000";
constant zero: STD_LOGIC_VECTOR(31 downto 0) := "00000000000000000000000000000000";
constant neg_zero: STD_LOGIC_VECTOR(31 downto 0) := "10000000000000000000000000000000";
constant highz: STD_LOGIC_VECTOR(31 downto 0) := "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ";
shared variable temp_result: STD_LOGIC_VECTOR(31 DOWNTO 0);

begin
  
PROCESS(latch) -- Latching the input values
BEGIN
  if(latch'event and (latch='1' or latch='H')) then A_in <= A; B_in <= B;
  end if;
END PROCESS;

PROCESS(a,b) -- Latching the input values
-- Procedures to process the adding operations
		PROCEDURE BINADD(L,R	: IN STD_LOGIC_VECTOR;
				 Cin	: IN STD_ULOGIC;
				 SUM	: OUT STD_LOGIC_VECTOR;
				 Cout	: OUT STD_ULOGIC) IS
		VARIABLE 	 Carry	: STD_ULOGIC; -- Internal Variable Carry
		BEGIN
			Carry:=Cin;
			FOR I IN L'REVERSE_RANGE LOOP
				SUM(I) := ((NOT(Carry)) AND (L(I) XOR R(I))) OR (Carry AND (L(I) XNOR R(I)));
				Carry  := (L(I) AND R(I)) OR (R(I) AND Carry) OR (L(I) AND Carry);
			END LOOP;
			Cout:=Carry;
		END BINADD;

-- Procedures to handle the multiplication   
		PROCEDURE multiplicating(L,R : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            				outer: OUT STD_LOGIC_VECTOR(31 DOWNTO 0)) IS
    		VARIABLE product, prod_term, buffering, productive : STD_LOGIC_VECTOR(47 DOWNTO 0) := "000000000000000000000000000000000000000000000000";
    		VARIABLE l_temp, l_var, r_temp : STD_LOGIC_VECTOR(23 DOWNTO 0);
    		VARIABLE sign, carry_out : STD_ULOGIC;
		VARIABLE exp_l, exp_r, exp_bin_out : STD_LOGIC_VECTOR(7 DOWNTO 0);
		VARIABLE exp_a, exp_b, exp_out : INTEGER;
		VARIABLE man_a, man_b, man_bin_out : STD_LOGIC_VECTOR(22 DOWNTO 0);
    		BEGIN
			sign := L(31) XOR R(31); outer(30 downto 23) := exp_bin_out; outer(22 downto 0) := man_bin_out; 
			exp_l := L(30 downto 23); exp_r := R(30 downto 23);
            		man_a := L(22 downto 0); man_b := R(22 downto 0);
			if(exp_l="00000000") 	then man_a := man_a(21 downto 0) & '0'; l_temp := '0' & man_a;
						else l_temp := '1' & man_a;
						end if;
			if(exp_r="00000000") 	then man_b := man_b(21 downto 0) & '0'; r_temp := '0' & man_b;
						else r_temp := '1' & man_b;
						end if;
            		productive(23 downto 0) := l_temp;
            	FOR I IN l_temp'reverse_range LOOP
              		IF(r_temp(I)='1') THEN
				BINADD(product, productive, '0', buffering, carry_out);
				product := buffering;
              		END IF;
              		productive := productive((productive'high-1) downto 0) & '0';
            	END LOOP;
		prod_term := product;

		exp_a := to_integer(unsigned(exp_l));
		exp_b := to_integer(unsigned(exp_r));
		exp_out := exp_a + exp_b - 127;

		--if(exp_a = 0) then exp_a := exp_a + 1; end if;
		--if(exp_b = 0) then exp_b := exp_b + 1; end if;

-- This is the part that me and Phillip will handle - the renormalization
-- I hope this won't be too different from the project we are going to do lol
		if(prod_term(47)='1') then prod_term := '0' & prod_term(47 downto 1); exp_out := exp_out + 1; 
		elsif(prod_term(47)='0' and prod_term(46)='0') then
		while(prod_term(46)/='1') loop
			prod_term := prod_term((prod_term'high-1) downto 0) & '0';
			exp_out := exp_out - 1;
			exit when prod_term(46)='1';		
		end loop;
		end if;
		
		if((exp_out > 255) and (sign = '0')) then outer := pos_inf;
		elsif((exp_out > 255) and (sign = '1')) then outer := neg_inf;
		elsif(exp_out <= 0) then 
			while(exp_out < 0) loop
				prod_term := '0' & prod_term(47 downto 1);
				exp_out := exp_out + 1;
			end loop;
			prod_term := '0' & prod_term(47 downto 1);
			exp_bin_out := std_logic_vector(to_unsigned(exp_out, 8));
			man_bin_out := prod_term(45 downto 23);
		else
			exp_bin_out := std_logic_vector(to_unsigned(exp_out, 8));
			man_bin_out := prod_term(45 downto 23);
		end if;
		outer := sign & exp_bin_out & man_bin_out;
    		END multiplicating;
    BEGIN
	if (A_in=NaN or B_in=NaN) then
		final_result <= NaN;

	elsif ((A_in(30 downto 23)="11111111" and B_in=zero) or (A_in(30 downto 23)="11111111" and B_in=neg_zero) or (A_in=zero and B_in(30 downto 23)="11111111") or (A_in=neg_zero and B_in(30 downto 23)="11111111")) then
		final_result <= NaN;
     	elsif((A_in=pos_inf and (B_in/=zero and B_in/=neg_zero and B_in(31)='0')) or 
                  (B_in=pos_inf and (A_in/=zero and A_in/=neg_zero and A_in(31)='0')) or 
                  (A_in=neg_inf and (B_in/=zero and B_in/=neg_zero and B_in(31)='1')) or 
                  (B_in=neg_inf and (A_in/=zero and A_in/=neg_zero and A_in(31)='1'))) then
		final_result <= pos_inf;
	elsif((A_in=pos_inf and (B_in/=zero and B_in/=neg_zero and B_in(31)='1')) or 
                  (B_in=pos_inf and (A_in/=zero and A_in/=neg_zero and A_in(31)='1')) or 
                  (A_in=neg_inf and (B_in/=zero and B_in/=neg_zero and B_in(31)='0')) or 
                  (B_in=neg_inf and (A_in/=zero and A_in/=neg_zero and A_in(31)='0'))) then
		final_result <= neg_inf; 
	elsif((A_in=zero and (B_in/=pos_inf and B_in/=neg_inf and B_in(31)='0')) or 
                  (B_in=zero and (A_in/=pos_inf and A_in/=neg_inf and A_in(31)='0')) or 
                  (A_in=neg_zero and (B_in/=pos_inf and B_in/=neg_inf and B_in(31)='1')) or 
                  (B_in=neg_zero and (A_in/=pos_inf and A_in/=neg_inf and A_in(31)='1'))) then
		final_result <= zero; 
	elsif((A_in=zero and (B_in/=pos_inf and B_in/=neg_inf and B_in(31)='1')) or 
                  (B_in=zero and (A_in/=pos_inf and A_in/=neg_inf and A_in(31)='1')) or 
                  (A_in=neg_zero and (B_in/=pos_inf and B_in/=neg_inf and B_in(31)='0')) or 
                  (B_in=neg_zero and (A_in/=pos_inf and A_in/=neg_inf and A_in(31)='0'))) then
		final_result <= neg_zero; 
	else
		multiplicating(A_in,B_in,temp_result);
                final_result <= temp_result;   
	end if;                           
END PROCESS;

PROCESS(drive) -- Driving the resultt to the output
begin
  if (drive='0' or drive='L') then C <= final_result;
              else C <= highz;
end if;
end process;
  
end behavioral;
