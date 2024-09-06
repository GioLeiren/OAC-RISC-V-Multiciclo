library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;

entity mem_rv is
    Port ( 
        clock   : in  std_logic;
        we      : in  std_logic;
        address : in  std_logic_vector(11 downto 0); -- 12-bit address bus
        datain  : in  std_logic_vector(31 downto 0); -- 32-bit data input
        dataout : out std_logic_vector(31 downto 0)  -- 32-bit data output
    );
end mem_rv;

architecture RTL of mem_rv is
    type mem_type is array (0 to 4095) of std_logic_vector(31 downto 0); -- 4K x 32-bit memory
    signal mem : mem_type;
    signal read_address : std_logic_vector(11 downto 0);


begin

    process(clock)
    begin
        if rising_edge(clock) then
            if we = '1' then
                mem(to_integer(unsigned(address))) <= datain; -- Write operation
            end if;
        end if;
	read_address <= address;
    end process;

    dataout <= mem(to_integer(unsigned(read_address))); -- Read operation
end RTL;

