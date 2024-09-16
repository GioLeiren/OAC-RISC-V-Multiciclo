library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;

entity testbench is end;
 
architecture testbench_arch of testbench is
 
 component controle is
    port (
        clock :in std_logic;
        input :in std_logic_vector(31 downto 0);
        inputAddress :in std_logic_vector(11 downto 0);
        memReady :in std_logic
    );
end component;

  signal clk :std_logic := '0';
  signal inputAddress :std_logic_vector(11 downto 0);
  signal memReady :std_logic := '0';
  signal input :std_logic_vector(31 downto 0);

  
begin
    u0: controle PORT MAP (clock => clk,
    					   input => input, 	
                           inputAddress => inputAddress,
                           memReady => memReady
                          );

	clk <= not clk after 1 ns;
    
    load_mem: process
      variable i : integer := 0;
      file text_file : text;
      file data_file : text;
      variable text_line : line;
      variable tmp :std_logic_vector(31 downto 0);
    begin
      file_open(text_file, "instrucoes.txt",  read_mode);
      file_open(data_file, "data.txt",  read_mode);
      
      -- Insercao de dados na area de instrucoes da memoria
      while not endfile(text_file) loop
        	readline(text_file, text_line);
            hread(text_line, tmp);
            input <= tmp;
            inputAddress <= std_logic_vector(to_unsigned(i, 12));
            i := i + 1;
            wait for 2 ns;
      end loop;
      
      i := 2048;
      -- Insercao de dados na area de dados da memoria
      while not endfile(data_file) loop
        	readline(data_file, text_line);
            hread(text_line, tmp);
            input <= tmp;
            inputAddress <= std_logic_vector(to_unsigned(i, 12));
            i := i + 1;
            wait for 2 ns;
      end loop;
      
      -- Sinaliza que a memoria foi inicializada corretamente
      memReady <= '1';
        wait;
  	end process;
 
END;