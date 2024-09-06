library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity XREGS is
    generic (WSIZE : natural := 32);
    port (
        clk, wren : in std_logic;
        rs1, rs2, rd : in std_logic_vector(4 downto 0);
        data : in std_logic_vector(WSIZE-1 downto 0);
        ro1, ro2 : out std_logic_vector(WSIZE-1 downto 0)
    );
end XREGS;

architecture xregs_arc of XREGS is
    type reg_array is array (31 downto 0) of std_logic_vector(WSIZE-1 downto 0);
    signal regs : reg_array := (others => (others => '0'));
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if wren = '1' then
                if rd /= "00000" then
                    regs(to_integer(unsigned(rd))) <= data;
                end if;
            end if;
        end if;
    end process;

    ro1 <= regs(to_integer(unsigned(rs1)));
    ro2 <= regs(to_integer(unsigned(rs2)));
end xregs_arc;

