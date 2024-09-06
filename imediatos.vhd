-- Code your design here
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.NUMERIC_STD.ALL;

entity genImm32 is
    Port (
        instr : in  std_logic_vector(31 downto 0);
        imm32 : out signed(31 downto 0)
    );
end genImm32;

architecture gen of genImm32 is
    type FORMAT_RV is (R_type, I_type, S_type, SB_type, UJ_type, U_type);
    signal format : FORMAT_RV;

begin
    process(instr)
    begin
        -- Determine the instruction format based on the opcode
        if instr(6 downto 0) = "0110011" then
		format <= R_type;
		imm32 <= x"00000000";
	elsif (instr(6 downto 0) = "0000011" or instr(6 downto 0) = "0010011" or instr(6 downto 0) = "1100111") then
		format <= I_type;
		if (instr(6 downto 0) = "0010011" and instr(14 downto 12) = "101" and instr(30) = '1') then
                    imm32 <= resize(signed(instr(24 downto 20)), 32);
                else
                    imm32 <= resize(signed(instr(31 downto 20)), 32);
                end if;
	elsif instr(6 downto 0) = "0100011" then
		format <= S_type;
		imm32 <= resize(signed(instr(31 downto 25) & instr(11 downto 7)), 32);
	elsif instr(6 downto 0) = "1100011" then
		format <= SB_type;
		imm32 <= resize(signed(instr(31) & instr(7) & instr(30 downto 25) & instr(11 downto 8) & '0'), 32);
	elsif instr(6 downto 0) = "1101111" then
		format <= UJ_type;
		imm32 <= resize(signed(instr(31) & instr(19 downto 12) & instr(20) & instr(30 downto 21) & '0'), 32);
	elsif instr(6 downto 0) = "0110111" then
		format <= U_type;
		imm32 <= resize(signed(instr(31 downto 12) & x"000"), 32);
	end if;
    end process;
end gen;


