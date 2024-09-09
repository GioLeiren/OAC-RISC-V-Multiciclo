library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

entity controle is 
    port (
        clock :in std_logic;
        input :in std_logic_vector(31 downto 0);
        inputAddress :in std_logic_vector(11 downto 0);
        memReady :in std_logic
    );
end controle;

architecture controle_arch of controle is

    component ulaRV is
        generic (WSIZE : natural := 32);
        port (
            opcode : in std_logic_vector(3 downto 0);
            A, B : in std_logic_vector(WSIZE-1 downto 0);
            Z : out std_logic_vector(WSIZE-1 downto 0)
            );
    end component;
    
    component mem_rv is
        port (
        clock : in std_logic;
        wren : in std_logic;
        address : in std_logic_vector(11 downto 0);
        datain : in std_logic_vector(31 downto 0);
        dataout : out std_logic_vector(31 downto 0)
        );
    end component;

    component XREGS is
        generic (WSIZE : natural := 32);
        port (
            clk, wren, rst : in std_logic;
            rs1, rs2, rd : in std_logic_vector(4 downto 0);
            data : in std_logic_vector(WSIZE-1 downto 0);
            ro1, ro2 : out std_logic_vector(WSIZE-1 downto 0)
          );
    end component;

    component genImm32 is
        port (
          instr : in std_logic_vector(31 downto 0);
          imm32 : out signed(31 downto 0)
        );
    end component;

    type state is (Etapa0, Etapa1, Etapa2, Etapa3, Etapa4, Etapa5);
    signal current_state :state := Etapa0;
    signal next_state :state;

    signal clk :std_logic;

    -- Sinais para o PC
    signal writePc :std_logic := '0';
    signal regNextPc :std_logic_vector(31 downto 0) := 32x"0";
    signal pc :std_logic_vector(31 downto 0) := 32x"0";
    signal branchEq :std_logic := '0';
    signal branchNe :std_logic := '0';
    signal zeroUla :std_logic;
    signal jump :std_logic := '0';


    -- Sinais para o RI
    signal writeRi :std_logic;
    signal ri :std_logic_vector(31 downto 0);

    -- Sinais para o PcBack
    signal writePcb :std_logic;
    signal pcBack :std_logic_vector(31 downto 0);

    -- Sinais para a memória
    signal writeMem :std_logic;
    signal readMem :std_logic := '0';
    signal memAddress :std_logic_vector(11 downto 0);
    signal dataIn :std_logic_vector(31 downto 0);
    signal dataOut :std_logic_vector(31 downto 0);
    signal regMem :std_logic_vector(31 downto 0);

    -- MUX Memoria
    signal muxAddress :std_logic_vector(1 downto 0);
    signal muxData :std_logic;

    -- Sinais para a ULA
    signal ulaOpcode :std_logic_vector(3 downto 0);
    signal entrada1Ula :std_logic_vector(31 downto 0);
    signal entrada2Ula :std_logic_vector(31 downto 0);
    signal saidaUla :std_logic_vector(31 downto 0);
    signal regUla :std_logic_vector(31 downto 0);
    signal writeRegUla :std_logic;

    -- MUX ULA
    signal muxUla1 :std_logic_vector(1 downto 0);
    signal muxUla2 :std_logic_vector(1 downto 0);
    signal muxSaidaUla :std_logic;

    -- Sinais para Banco de Registradores
    signal writeReg :std_logic := '0';
    signal resetReg :std_logic := '0';
    signal rs1Reg :std_logic_vector(4 downto 0);
    signal rs2Reg :std_logic_vector(4 downto 0);
    signal rdReg :std_logic_vector(4 downto 0);
    signal dataInReg :std_logic_vector(31 downto 0);
    signal regSaida1 :std_logic_vector(31 downto 0);
    signal regSaida2 :std_logic_vector(31 downto 0);

    -- MUX Reg
    signal muxReg :std_logic_vector(1 downto 0);

    -- Sinais para o gerador de imediatos
    signal imediato :signed(31 downto 0);
    
    -- Sinais para Controle da ULA
    signal opCode :std_logic_vector(6 downto 0) := 7x"0";
    signal funct3 :std_logic_vector(2 downto 0);
    signal funct7 :std_logic_vector(6 downto 0);
    
    --Outros sinais controle
    signal estado :std_logic_vector(2 downto 0) := "000";


begin
    clk <= clock;

    memoria: mem_rv port map (clock => clk, 
                            wren => writeMem, 
                            address => memAddress, 
                            datain => dataIn,
                            dataout => dataOut
                            );

    ula: ulaRV port map (opcode => ulaOpcode,
                        A => entrada1Ula,
                        B => entrada2Ula,
                        Z => saidaUla
                        );

    registradores: XREGS port map(clk => clk,
                                  wren => writeReg,
                                  rst => resetReg,
                                  rs1 => rs1Reg,
                                  rs2 => rs2Reg,
                                  rd => rdReg,
                                  data => dataInReg,
                                  ro1 => regSaida1,
                                  ro2 => regSaida2
                                 );

    gerador_imediato: genImm32 port map(
                                        instr => ri,
                                        imm32 => imediato
                                        );

    

    sync_process: process (clk, memReady)
    begin
        if rising_edge(clk) then
            if estado = "000" and memReady = '1' then
                current_state <= Etapa1;
            else
                current_state <= next_state;
            end if;
        end if;
        
    end process;

    comb_process: process (current_state)
    begin
        case current_state is
            when Etapa0 =>
                estado <= "000";
                    
                muxAddress <= "01";
                writeMem <= '1';
                muxData <= '1';
                                
            when Etapa1 =>  
                estado <= "001";
                
                -- Caso tenha ocorrido uma instrução de branch, atualizar PC
                if (branchEq = '1' and zeroUla = '1') or (branchNe = '1' and zeroUla = '0') or (jump = '1')then
                    pc <= regNextPc;
                end if;

                -- Desliga a escrita no Registrador rd
                writeReg <= '0';
                    
                -- Desliga a entrada de dados pelo testbench    
                muxData <= '0';

                -- Seleciona o PC no Mux do Endereço
                muxAddress <= "00";

                -- Lê a memória no endereço de PC
                writeMem <= '0';
                readMem <= '1';

                -- Escreve PC no PcBack
                writePcb <= '1';

                -- Seleciona o PC na Entrada 1 da ULA
                muxUla1 <= "01";
                -- Seleciona o 4 na Entrada 2 da ULA
                muxUla2 <= "01";
                -- Operação de Soma
                ulaOpcode <= 4x"0";

                -- Seleciona a saída da ULA para atribuir a PC
                muxSaidaUla <= '0';
                
                -- Libera a escrita de regNextPc
                writePc <= '1';
                
                next_state <= Etapa2;
            when Etapa2 =>
                estado <= "010";
                
                branchEq <= '0';
                branchNe <= '0';
                jump <= '0';
                
                -- Salva o conteúdo lido em RI
                writeRi <= '1';
                               
                -- Altera o valor de Pc para Pc+4
                pc <= regNextPc;
                
                -- Desliga a escrita de Pc
                writePc <= '0';
                
                -- Desliga a escrita de PcBack
                writePcb <= '0';

				
				-- Seleciona PcBack na entrada 1 da ULA
                muxUla1 <= "00";
                -- Seleciona Imediato << 1 na entrada 2 da ULA
                muxUla2 <= "11";
                -- Operação de Soma
                ulaOpcode <= 4x"0";
                
                -- Salva o resultado no Registrador da ULA
                writeRegUla <= '1';
                
                next_state <= Etapa3;

            when Etapa3 =>
            	estado <= "011";
                writeMem <= '0';
                readMem <= '0';
                writeRegUla <= '1';
                
                -- Desliga a escrita de RI
                writeRi <= '0';
                
                case Opcode is
                    when 7x"17" => -- AUIPC
                        next_state <= Etapa4;

                        -- Seleciona PcBack na ULA
                        muxUla1 <= "00";
                        -- Seleciona o Imediato
                        muxUla2 <= "10";
                        -- Op de soma
                        ulaOpcode <= 4x"0";
                    
                    when 7x"63" => -- Branch
                        next_state <= Etapa1;

                        -- Seleciona rs1
                        muxUla1 <= "10";
                        -- Seleciona o rs2
                        muxUla2 <= "00";
                        -- Op de subtração
                        ulaOpcode <= 4x"1";
                        -- Desliga a escrita no registrador da ULA
                        writeRegUla <= '0';
                        -- Seleciona o registrador da ULA para atribuir a PC
                		muxSaidaUla <= '1';
                        -- Liga a escrita de regNextPc
                        writePc <= '1';
                        
                        case funct3 is
                        	when "000" =>
                            	-- Sinal que indica branchEq
                        		branchEq <= '1';
                            when "001" =>
                            	-- Sinal que indica branchNe
                            	branchNe <= '1';
                            when others =>
                        end case;
                        
                    when 7x"13" => -- RI_Type
                        next_state <= Etapa4;

                        -- Seleciona rs1
                        muxUla1 <= "10";
                        -- Seleciona o Imediato
                        muxUla2 <= "10";

                        case funct3 is
                            when "000" => -- ADDi
                                ulaOpcode <= 4x"0";

                            when "100" => -- XORi
                                ulaOpcode <= "0100";

                            when "110" => -- ORi
                                ulaOpcode <= "0011";

                            when "111" => -- ANDi
                                ulaOpcode <= "0010";

                            when others =>
                        end case;

                        
                    
                    when 7x"6F" => -- JAL
                        next_state <= Etapa1;

                        -- Seleciona o registrador da ULA para atribuir a PC
                		muxSaidaUla <= '1';
                        -- Liga a escrita de regNextPc
                        writePc <= '1';

                        -- Liga a escrita no registrador rd
                        writeReg <= '1';
                        -- Seleciona PC para escrita (nesse caso pc+4)
                        muxReg <= "01";

                        -- Sinal que indica JUNP
                        jump <= '1';                        
                        
                    when 7x"67" => -- JALR
                        next_state <= Etapa1;

                    	-- Seleciona rs1
                        muxUla1 <= "10";
                        -- Seleciona o Imediato
                        muxUla2 <= "10";
                        -- Seleciona o registrador da ULA para atribuir a PC
                		muxSaidaUla <= '1';
                        -- Liga a escrita de regNextPc
                        writePc <= '1';
                        
                         -- Liga a escrita no registrador rd
                        writeReg <= '1';
                        -- Seleciona PC para escrita (nesse caso pc+4)
                        muxReg <= "01";

                        -- Sinal que indica JUMP
                        jump <= '1';
              
                    when 7x"33" => -- R_Type
                        next_state <= Etapa4;

                    	-- Seleciona rs1
                        muxUla1 <= "10";
                        -- Seleciona o rs2
                        muxUla2 <= "00";

                        case funct3 is
                            when "000" => -- ADD/SUB
                                case funct7 is
                                    when 7x"0" =>
                                        -- Op de soma
                                        ulaOpcode <= 4x"0";

                                    when 7x"20" =>
                                        -- Op de subtração
                                        ulaOpcode <= 4x"1";

                                    when others =>
                                end case;
                                
                            when "111" => -- AND
                                ulaOpcode <= "0010";

                            when "110" => -- OR
                                ulaOpcode <= "0011";

                            when "100" => -- XOR
                                ulaOpcode <= "0100";

                            when "010" => -- SLT
                                ulaOpcode <= "1000";

                            when others =>
                        end case;
                                
                    when 7x"23" | 7x"3" => -- SW | LW
                        next_state <= Etapa4;

                        -- Seleciona rs1
                        muxUla1 <= "10";
                        -- Seleciona o Imediato
                        muxUla2 <= "10";
                        -- Op de soma
                        ulaOpcode <= 4x"0";

                    when 7x"37" => -- LUI
                        next_state <= Etapa1;

                        -- Seleciona o imediato para escrita em rd
                        muxReg <= "10";
                        -- Liga a escrita no registrador RD
                        writeReg <= '1';

                    when others =>

                end case;
                
            when Etapa4 =>
            	estado <= "100";

                case Opcode is
                    when 7x"17" | 7x"33" | 7x"13" => -- AUIPC | R_Type | RI_Type
                        next_state <= Etapa1;
                        -- Liga a escrita no registrador RD
                        writeReg <= '1';
                        -- Seleciona a saída da ULA para escrita
                        muxReg <= "00";

                    when 7x"3" => -- LW
                        next_state <= Etapa5;

                        -- Liga a leitura da Memória
                        readMem <= '1';
                        -- Seleciona saída da ULA para o endereço de leitura
                        muxAddress <= "10";

                    when 7x"23" => -- SW
                        next_state <= Etapa1;

                        -- Seleciona a saída do registrador rs2 para escrita
                        muxData <= '0';
                        -- Seleciona a saída da ULA como endereço de escrita
                        muxAddress <= "10";
                        -- Liga a escrita da memória
                        writeMem <= '1';
   
                    when others =>
                end case;

            when Etapa5 =>
                estado <= "101";

				case opCode is
                  when 7x"3" => -- LW
                      -- Liga a escrita no registrador RD
                      writeReg <= '1';
                      -- Seleciona o registrador da memória para escrita
                      muxReg <= "11";
                      
                  when others => 
                end case;
            	
                next_state <= Etapa1;
        end case;
        
    end process;

   
    
    

    -- #################################### PC ####################################

    -- Mux Saida da ULA (Escrita em PC):
    regNextPc <= saidaUla  when muxSaidaUla = '0' and writePc = '1' else
                 regUla    when muxSaidaUla = '1' and writePc = '1';
    
    -- Salva PC em Pcback
    pcBack <= pc when writePcb = '1';

    -- Lê a instrução em RI
    ri <= regMem when writeRi = '1';

    -- #################################### MEMORIA ####################################

    --Mux Endereço Memória:
    -- Dividindo endereços por 4 já que 1 endereço de memória corresponde a 1 elemento do vetor
    memAddress <= pc(13 downto 2)           when muxAddress = "00" else
                  inputAddress              when muxAddress = "01" else
                  regUla(13 downto 2)       when muxAddress = "10";

    -- MUX Entrada de Dados Memória
    dataIn <=   regSaida2 when muxData = '0' else
                input     when muxData = '1';

    -- Salva a saída da memória no registrador de dados
    regMem <= dataOut when readMem = '1';

    -- #################################### INSTRUCAO ####################################

    -- Instrução
    opCode <= ri(6 downto 0);
    funct3 <= ri(14 downto 12);
    funct7 <= ri(31 downto 25);

    -- #################################### ULA ####################################

    -- Mux ULA 1:
    entrada1Ula <= pcBack  when muxUla1 = "00" else
                   pc      when muxUla1 = "01" else
                   regSaida1        when muxUla1 = "10";
    
    -- Mux ULA 2:               
    entrada2Ula <= 32x"4"                                    when muxUla2 = "01" else
                   regSaida2                                 when muxUla2 = "00" else
                   std_logic_vector(imediato)                when muxUla2 = "10" else
                   std_logic_vector(shift_left(imediato, 1)) when muxUla2 = "11";
                   
    -- Registrador da ULA               
    regUla <= saidaUla when writeRegUla = '1';

    -- Zero da ULA para Branch
    zeroUla <= '1' when saidaUla = 32x"0" else
                '0';

    
    -- #################################### REGISTRADORES ####################################

    -- Registradores
    rs1Reg <= ri(19 downto 15);
    rs2Reg <= ri(24 downto 20);
    rdReg <= ri(11 downto 7);

    -- MUX para escrita do registrador
    dataInReg <= regUla                      when muxReg = "00" else
                 pc                          when muxReg = "01" else
                 std_logic_vector(imediato)  when muxReg = "10" else
                 regMem                      when muxReg = "11";

    
    
end controle_arch;