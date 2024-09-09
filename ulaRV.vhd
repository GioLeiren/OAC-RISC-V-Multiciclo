library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ulaRV is
    generic (WSIZE : natural := 32);
    port (
        opcode: in std_logic_vector(3 downto 0);
        A, B: in std_logic_vector(WSIZE-1 downto 0);
        Z: out std_logic_vector(WSIZE-1 downto 0);
        cond: out std_logic
    );
end ulaRV;

architecture ulaRV_arch of ulaRV is
    begin 
        process(Z, A, B, opcode, cond)
        begin
            case opcode is
                when "0000" => Z <= std_logic_vector(signed(A) + signed(B));
                when "0001" => Z <= std_logic_vector(signed(A) + signed(B));
                when "0010" => Z <= A and B;
                when "0011" => Z <= A or B;
                when "0100" => Z <= A xor B;
                when "0101" => Z <= A sll to_integer(unsigned(B));
                when "0110" => Z <= A srl to_integer(unsigned(B));
                when "0111" => Z <= std_logic_vector(shift_right(signed(A), to_integer(unsigned(B))));
                when "1000" =>
                            if signed(A) < signed(B) then
                                cond <= '1';
                            else
                                cond <= '0';
                            end if;
                when "1001" =>
                            if signed(A) < signed(B) then
                                cond <= '1';
                            else
                                cond <= '0';
                            end if;
                when "1010" =>
                            if signed(A) >= signed(B) then
                                cond <= '1';
                            else
                                cond <= '0';
                            end if;
                when "1011" =>
                            if signed(A) >= signed(B) then
                                cond <= '1';
                            else
                                cond <= '0';
                            end if;
                when "1100" =>
                            if A = B then
                                cond <= '1';
                            else
                                cond <= '0';
                            end if;
                when "1101" =>
                            if A /= B then
                                cond <= '1';
                            else
                                cond <= '0';
                            end if;
                when others =>
            end case;
        end process;
end ulaRV_arch;
