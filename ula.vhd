library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ulaRV is
    generic (WSIZE : natural := 32);
    port (
        opcode : in std_logic_vector(3 downto 0);
        A, B   : in std_logic_vector(WSIZE-1 downto 0);
        Z      : out std_logic_vector(WSIZE-1 downto 0);
        cond   : out std_logic
    );
end ulaRV;

architecture ula_arc of ulaRV is
    signal out32 : std_logic_vector(31 downto 0);
begin
    Z <= out32;

    process(A, B, opcode, out32)
    begin
        if opcode = "0000" then
            -- ADD
            out32 <= std_logic_vector(signed(A) + signed(B));
        elsif opcode = "0001" then
            -- SUB
            out32 <= std_logic_vector(signed(A) - signed(B));
	elsif opcode = "0010" then
            -- AND
            out32 <= A and B;
	elsif opcode = "0011" then
            -- OR
            out32 <= A or B;
	elsif opcode = "0100" then
            -- XOR
            out32 <= A xor B;
	elsif opcode = "0101" then
            -- SLL
            out32 <= std_logic_vector(shift_left(unsigned(A), to_integer(unsigned(B(4 downto 0)))));
	elsif opcode = "0110" then
            -- SRL
            out32 <= std_logic_vector(shift_right(unsigned(A), to_integer(unsigned(B(4 downto 0)))));
	elsif opcode = "0111" then
            -- SRA
            out32 <= std_logic_vector(shift_right(signed(A), to_integer(unsigned(B(4 downto 0)))));
	elsif opcode = "1000" then
            -- SLT
            if to_integer(signed(A)) < to_integer(signed(B)) then
                out32 <= x"00000001";
            else
                out32 <= x"00000000";
            end if;
	elsif opcode = "1001" then
            -- SLTU
            if to_integer(unsigned(A)) < to_integer(unsigned(B)) then
                out32 <= x"00000001";
            else
                out32 <= x"00000000";
            end if;
	elsif opcode = "1010" then
            -- SGE
            if to_integer(signed(A)) >= to_integer(signed(B)) then
                out32 <= x"00000001";
            else
                out32 <= x"00000000";
            end if;
        elsif opcode = "1011" then
            -- SGEU
            if to_integer(unsigned(A)) >= to_integer(unsigned(B)) then
                out32 <= x"00000001";
            else
                out32 <= x"00000000";
            end if;
	elsif opcode = "1100" then
            -- SEQ
            if to_integer(signed(A)) = to_integer(signed(B)) then
                out32 <= x"00000001";
            else
                out32 <= x"00000000";
            end if;
        elsif opcode = "1101" then
            -- SNE
            if to_integer(signed(A)) /= to_integer(signed(B)) then
                out32 <= x"00000001";
            else
                out32 <= x"00000000";
            end if;
        end if;
    end process;
end ula_arc;

