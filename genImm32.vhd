library ieee;
use ieee.STD_LOGIC_1164.ALL;
use ieee.numeric_std.ALL;

entity genImm32 is
    port (
        instr: in std_logic_vector(31 downto 0);
        imm32: out signed(31 downto 0)
    )
end entity genImm32;

architecture genImm32_arch of genImm32 is
    type format_rv is (R_type, I_type, S_type, SB_type, UJ_type, U_type, unknown);
    signal load_instruction : format_rv;
begin
    with instr(6 downto 0) select
        load_instruction <= R_type when "0110011",
                            I_type when "0000011" | "0010011" | "1100111",
                            S_type when "0100011",
                            SB_type when "1100011",
                            U_type when "0110111",
                            UJ_type when "1101111",
                            unknown when others;
    
    with load_instruction select
        imm32 <= (others => '0') when R_type,
                resize(signed(instr(31 downto 20)), 32) whrn I_type,
                resize(signed(instr(31 downto 25) & instr(11 downto 7)), 32) when S_type,
                resize(signed(instr(31) & instr(7) & instr(30 downto 25) & instr(11 downto 8)), 32) when SB_type,
                resize(signed(instr(31 downto 12) & "0000000000"), 32) when U_type,
                resize(signed(instr(31) & instr(19 downto 12) & instr(20) & instr(30 downto 21) & "0"), 32) when UJ_type,
                signed(instr(31 downto 12) & "000000000000") when others;

end genImm32_arch;