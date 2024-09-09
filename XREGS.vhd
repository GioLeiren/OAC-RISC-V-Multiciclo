    library IEEE;
    use IEEE.std_logic_1164.all;
    use ieee.numeric_std.all;

    entity XREGS is
    generic (WSIZE : natural := 32);
    port (
        clk, wren, rst : in std_logic;
        rs1, rs2, rd : in std_logic_vector(4 downto 0);
        data : in std_logic_vector(WSIZE-1 downto 0);
        ro1, ro2 : out std_logic_vector(WSIZE-1 downto 0)
        );
    end XREGS;

    architecture XREGS_arch of XREGS is

    type registradores is array (natural range <>) of std_logic_vector (31 downto 0);

    signal breg :registradores(31 downto 0) := (others => (others =>'0'));

    begin
        sync_process: process(clk)
        begin           
            if rising_edge(clk) then
                if rst = '1' then
                    breg <= (others => (others =>'0'));
                    
                elsif wren = '1' then
                    if to_integer(unsigned(rd)) /= 0 then
                        breg(to_integer(unsigned(rd))) <= data;
                    end if;
                    
                else
                    ro1 <= breg(to_integer(unsigned(rs1)));
                    ro2 <= breg(to_integer(unsigned(rs2)));
                end if;
            end if;
        end process;    
    end XREGS_arch;