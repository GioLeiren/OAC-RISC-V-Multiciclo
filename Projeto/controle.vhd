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
            clk, wren : in std_logic;
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

    component ulaRV is
        generic (WSIZE : natural := 32);
        port (
            opcode : in std_logic_vector(3 downto 0);
            A, B : in std_logic_vector(WSIZE-1 downto 0);
            Z : out std_logic_vector(WSIZE-1 downto 0)
            );
    end component;

    type estado is (Inicio, Fetch, Decode, Execute, Memory, WriteBack);
    signal estado_atual :estado := Inicio;
    signal prox_estado :estado;

    signal clk :std_logic;

    -- Sinais para o PC
    signal escrevePC :std_logic := '0';
    signal regNextPc :std_logic_vector(31 downto 0) := x"00000000";
    signal pc :std_logic_vector(31 downto 0) := x"00000000";
    signal branchEq :std_logic := '0';
    signal branchNe :std_logic := '0';
    signal branchBlGe :std_logic := '0';
    signal zeroUla :std_logic;
    signal bgeUla :std_logic;
    signal jump :std_logic := '0';


    -- Sinais para o RI
    signal escreveIR :std_logic;
    signal ri :std_logic_vector(31 downto 0);

    -- Sinais para o PcBack
    signal escrevePCB :std_logic;
    signal pcBack :std_logic_vector(31 downto 0);

    -- Sinais para a memaria
    signal escreveMem :std_logic;
    signal leMem :std_logic := '0';
    signal memAddress :std_logic_vector(11 downto 0);
    signal dataIn :std_logic_vector(31 downto 0);
    signal dataOut :std_logic_vector(31 downto 0);
    signal regMem :std_logic_vector(31 downto 0);

    -- MUX Memoria
    signal muxAddress :std_logic_vector(1 downto 0);
    signal muxData :std_logic;

    -- Sinais para a ULA
    signal ulaOpcode :std_logic_vector(3 downto 0);
    signal entradaAUla :std_logic_vector(31 downto 0);
    signal entradaBUla :std_logic_vector(31 downto 0);
    signal saidaUla :std_logic_vector(31 downto 0);
    signal regUla :std_logic_vector(31 downto 0);
    signal escreveRegUla :std_logic;

    -- MUX ULA
    signal muxUla1 :std_logic_vector(1 downto 0);
    signal muxUla2 :std_logic_vector(1 downto 0);
    signal muxSaidaUla :std_logic;

    -- Sinais para Banco de Registradores
    signal escreveReg :std_logic := '0';
    signal rs1Reg :std_logic_vector(4 downto 0);
    signal rs2Reg :std_logic_vector(4 downto 0);
    signal rdReg :std_logic_vector(4 downto 0);
    signal dataInReg :std_logic_vector(31 downto 0);
    signal regSaidaA :std_logic_vector(31 downto 0);
    signal regSaidaB :std_logic_vector(31 downto 0);

    -- MUX Reg
    signal muxReg :std_logic_vector(1 downto 0);

    -- Sinais para o gerador de imediatos
    signal imediato :signed(31 downto 0);
    
    -- Sinais para Controle do Multiciclo e da ULA
    signal opCode :std_logic_vector(6 downto 0) := "0000000";
    signal funct3 :std_logic_vector(2 downto 0);
    signal funct7 :std_logic_vector(6 downto 0);


begin
    clk <= clock;

    memoria: mem_rv port map (clock => clk, 
                            wren => escreveMem, 
                            address => memAddress, 
                            datain => dataIn,
                            dataout => dataOut
                            );

    registradores: XREGS port map(clk => clk,
                                  wren => escreveReg,
                                  rs1 => rs1Reg,
                                  rs2 => rs2Reg,
                                  rd => rdReg,
                                  data => dataInReg,
                                  ro1 => regSaidaA,
                                  ro2 => regSaidaB
                                 );

    gerador_imediato: genImm32 port map(
                                        instr => ri,
                                        imm32 => imediato
                                        );
    
    ula: ulaRV port map (opcode => ulaOpcode,
                        A => entradaAUla,
                        B => entradaBUla,
                        Z => saidaUla
                        );

    sync_process: process (clk, memReady)
    begin
        if rising_edge(clk) then
            if estado_atual = Inicio and memReady = '1' then
                estado_atual <= Fetch;
            else
                estado_atual <= prox_estado;
            end if;
        end if;
        
    end process;

    comb_process: process (estado_atual)
    begin
        case estado_atual is
            when Inicio =>
                    
                muxAddress <= "01";
                escreveMem <= '1';
                muxData <= '1';
                                
            when Fetch =>  
                
                -- Atualiza PC caso tenha ocorrido um salto
                if (branchEq = '1' and zeroUla = '1') or (branchNe = '1' and zeroUla = '0') or (branchBlGe = '1' and bgeUla = '1') or (branchBlGe = '1' and bgeUla = '0') or (jump = '1') then
                    pc <= regNextPc;
                end if;

                -- Desativa a escrita no Banco de Registradores
                escreveReg <= '0';
                    
                -- Desativa a entrada de dados pelo testbench    
                muxData <= '0';

                -- Seleciona o PC no Mux do Endereco
                muxAddress <= "00";

                -- Ativa a leitura da memoria
                escreveMem <= '0';
                leMem <= '1';

                -- Ativa a escrita no registrador PCBack
                escrevePCB <= '1';

                -- Seleciona o PC na Entrada 1 da ULA
                muxUla1 <= "01";
                -- Seleciona o inteiro 4 na Entrada 2 da ULA
                muxUla2 <= "01";
                -- Operacao de Soma
                ulaOpcode <= "0000";

                -- Seleciona a saida da ULA para atribuir a PC
                muxSaidaUla <= '0';
                
                -- Libera a escrita de regNextPc (buffer auxiliar do PC)
                escrevePC <= '1';
                
                prox_estado <= Decode;
            when Decode =>
                
                branchEq <= '0';
                branchNe <= '0';
                branchBlGe <= '0';
                jump <= '0';
                
                -- Ativa a escrita em RI
                escreveIR <= '1';
                               
                -- Atualiza o valor de PC para PC+4
                pc <= regNextPc;
                
                -- Desativa a escrita de PC
                escrevePC <= '0';
                
                -- Desativa a escrita de PCBack
                escrevePCB <= '0';

				
				-- Seleciona PCBack na entrada 1 da ULA
                muxUla1 <= "00";
                -- Seleciona Imediato deslocado na entrada 2 da ULA
                muxUla2 <= "11";
                -- Seleciona operacao ADD na ULA
                ulaOpcode <= "0000";
                
                -- Salva o resultado no Registrador saidaULA
                escreveRegUla <= '1';
                
                prox_estado <= Execute;

            when Execute =>
                escreveMem <= '0';
                leMem <= '0';
                escreveRegUla <= '1';
                
                -- Desativa a escrita em RI
                escreveIR <= '0';
                
                case Opcode is
                    when "0010111" => -- AUIPC
                        prox_estado <= WriteBack;

                        -- Seleciona PCBack na entrada 1 da ULA
                        muxUla1 <= "00";
                        -- Seleciona o Imediato na entrada 2 da ULA
                        muxUla2 <= "10";
                        -- Seleciona operacao ADD na ULA
                        ulaOpcode <= "0000";
                    
                    when "1100011" => -- Branch
                        prox_estado <= Fetch;

                        -- Seleciona rs1 na entrada 1 da ULA
                        muxUla1 <= "10";
                        -- Seleciona o rs2 na entrada 2 da ULA
                        muxUla2 <= "00";
                        -- Seleciona operacao SUB na ULA
                        ulaOpcode <= "0001";
                        -- Desativa a escrita no registrador saidaULA
                        escreveRegUla <= '0';
                        -- Seleciona o registrador saidaULA para atribuir a PC
                		muxSaidaUla <= '1';
                        -- Ativa a escrita de regNextPc
                        escrevePC <= '1';
                        
                        case funct3 is
                        	when "000" =>
                            	-- Sinal que indica branchEq
                        		branchEq <= '1';
                            when "001" =>
                            	-- Sinal que indica branchNe
                            	branchNe <= '1';
                            when "100" =>
                            	-- Sinal que indica branchBlGe/branchLt
                            	branchBlGe <= '1';
                            when "101" =>
                            	-- Sinal que indica branchBlGe/branchLt
                            	branchBlGe <= '1';
                            when others =>
                        end case;
                        
                    when "0010011" => -- RI_Type
                        prox_estado <= WriteBack;

                        -- Seleciona rs1 na entrada 1 da ULA
                        muxUla1 <= "10";
                        -- Seleciona o Imediato na entrada 2 da ULA
                        muxUla2 <= "10";

                        case funct3 is
                            when "000" => -- ADDI
                                ulaOpcode <= "0000";

                            when "100" => -- XORI
                                ulaOpcode <= "0100";

                            when "110" => -- ORI
                                ulaOpcode <= "0011";

                            when "111" => -- ANDI
                                ulaOpcode <= "0010";
                            
                            when "010" => -- SLTI
                                ulaOpcode <= "1000";
                            
                            when "011" => -- SLTIU
                                ulaOpcode <= "1001";
                            
                            when "001" => -- SLLI
                                ulaOpcode <= "0101";
                            
                            when "101" => -- SRLI/SRAI
                                case funct7 is
                                    when "0000000" =>
                                        -- Seleciona operacao SRL na ULA
                                        ulaOpcode <= "0110";

                                    when "0100000" =>
                                        -- Seleciona operacao SRA na ULA
                                        ulaOpcode <= "0111";

                                    when others =>
                                end case;

                            when others =>
                        end case;

                        
                    
                    when "1101111" => -- JAL
                        prox_estado <= Fetch;

                        -- Seleciona o registrador saidaULA para atribuir a PC
                		muxSaidaUla <= '1';
                        -- Ativa a escrita de regNextPc
                        escrevePC <= '1';

                        -- Ativa a escrita no Banco de Registradores
                        escreveReg <= '1';
                        -- Seleciona PC para escrita (nesse caso pc+4)
                        muxReg <= "01";

                        -- Sinal que indica JUMP
                        jump <= '1';                        
                        
                    when "1100111" => -- JALR
                        prox_estado <= Fetch;

                    	-- Seleciona rs1 na entrada 1 da ULA
                        muxUla1 <= "10";
                        -- Seleciona o Imediato na entrada 2 da ULA
                        muxUla2 <= "10";
                        -- Seleciona o registrador saidaULA para atribuir a PC
                		muxSaidaUla <= '1';
                        -- Ativa a escrita de regNextPc
                        escrevePC <= '1';
                        
                         -- Ativa a escrita no Banco de Registradores
                        escreveReg <= '1';
                        -- Seleciona PC para escrita (nesse caso pc+4)
                        muxReg <= "01";

                        -- Sinal que indica JUMP
                        jump <= '1';
              
                    when "0110011" => -- R_Type
                        prox_estado <= WriteBack;

                    	-- Seleciona rs1 na entrada 1 da ULA
                        muxUla1 <= "10";
                        -- Seleciona o rs2 na entrada 2 da ULA
                        muxUla2 <= "00";

                        case funct3 is
                            when "000" => -- ADD/SUB
                                case funct7 is
                                    when "0000000" =>
                                        -- Seleciona operacao ADD na ULA
                                        ulaOpcode <= "0000";

                                    when "0100000" =>
                                        -- Seleciona operacao SUB na ULA
                                        ulaOpcode <= "0001";

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
                            
                            when "011" => -- SLTU
                                ulaOpcode <= "1001";
                            
                            when "001" => -- SLL
                                ulaOpcode <= "0101";
                            
                            when "101" => -- SRL/SRA
                                case funct7 is
                                    when "0000000" =>
                                        -- Seleciona operacao SRL na ULA
                                        ulaOpcode <= "0110";

                                    when "0100000" =>
                                        -- Seleciona operacao SRA na ULA
                                        ulaOpcode <= "0111";

                                    when others =>
                                end case;

                            when others =>
                        end case;
                                
                    when "0100011" | "0000011" => -- SW | LW
                        prox_estado <= Memory;

                        -- Seleciona rs1 na entrada 1 da ULA
                        muxUla1 <= "10";
                        -- Seleciona o Imediato na entrada 2 da ULA
                        muxUla2 <= "10";
                        -- Seleciona operacao ADD na ULA
                        ulaOpcode <= "0000";

                    when "0110111" => -- LUI
                        prox_estado <= Fetch;

                        -- Seleciona o imediato para escrita em rd
                        muxReg <= "10";
                        -- Ativa a escrita no Banco de Registradores
                        escreveReg <= '1';

                    when others =>

                end case;
                
            when Memory =>

                case Opcode is

                    when "0000011" => -- LW
                        prox_estado <= WriteBack;

                        -- Ativa a leitura da Memoria
                        leMem <= '1';
                        -- Seleciona saidaULA para o endereco de leitura
                        muxAddress <= "10";

                    when "0100011" => -- SW
                        prox_estado <= Fetch;

                        -- Seleciona a saida do registrador rs2 para escrita
                        muxData <= '0';
                        -- Seleciona saidaULA como endereco de escrita
                        muxAddress <= "10";
                        -- Ativa a escrita da memoria
                        escreveMem <= '1';
   
                    when others =>
                end case;

            when WriteBack =>

				case opCode is
                  when "0010111" | "0110011" | "0010011" => -- AUIPC | R_Type | RI_Type
                        prox_estado <= Fetch;
                        -- Ativa a escrita no Banco de Registradores
                        escreveReg <= '1';
                        -- Seleciona saidaULA para escrita
                        muxReg <= "00";

                  when "0000011" => -- LW
                      -- Ativa a escrita no Banco de Registradores
                      escreveReg <= '1';
                      -- Seleciona o registrador da memoria de dados para escrita
                      muxReg <= "11";
                      
                  when others => 
                end case;
            	
                prox_estado <= Fetch;
        end case;
        
    end process;


    -- Mux da saida da ULA e do registrador saidaULA (Escrita em PC):
    regNextPc <= saidaUla  when muxSaidaUla = '0' and escrevePC = '1' else
                 regUla    when muxSaidaUla = '1' and escrevePC = '1';
    
    -- Salva PC em PCBack
    pcBack <= pc when escrevePCB = '1';

    -- Le a instrucao em RI
    ri <= regMem when escreveIR = '1';



    --Mux Endereco Memoria:
    -- Dividindo enderecos por 4 para saltar words
    memAddress <= pc(13 downto 2)           when muxAddress = "00" else
                  inputAddress              when muxAddress = "01" else
                  regUla(13 downto 2)       when muxAddress = "10";

    -- MUX Entrada de Dados Memoria
    dataIn <=   regSaidaB when muxData = '0' else
                input     when muxData = '1';

    -- Salva a saida da memoria no registrador de dados da memoria
    regMem <= dataOut when leMem = '1';



    -- Instrucao
    opCode <= ri(6 downto 0);
    funct3 <= ri(14 downto 12);
    funct7 <= ri(31 downto 25);



    -- Mux entrada ULA 1:
    entradaAUla <= pcBack  when muxUla1 = "00" else
                   pc      when muxUla1 = "01" else
                   regSaidaA        when muxUla1 = "10";
    
    -- Mux entrada ULA 2:               
    entradaBUla <= x"00000004"                               when muxUla2 = "01" else
                   regSaidaB                                 when muxUla2 = "00" else
                   std_logic_vector(imediato)                when muxUla2 = "10" else
                   std_logic_vector(shift_left(imediato, 1)) when muxUla2 = "11";
                   
    -- Registrador da ULA (saidaULA)             
    regUla <= saidaUla when escreveRegUla = '1';

    -- Zero da ULA para Branch
    zeroUla <= '1' when saidaUla = x"00000000" else
                '0';
    
    bgeUla <= '1' when signed(saidaUla) > 0 else 
                '0';

    


    -- Enderecos dos registradores
    rs1Reg <= ri(19 downto 15);
    rs2Reg <= ri(24 downto 20);
    rdReg <= ri(11 downto 7);

    -- MUX para escrita no Banco de Registradores
    dataInReg <= regUla                      when muxReg = "00" else
                 pc                          when muxReg = "01" else
                 std_logic_vector(imediato)  when muxReg = "10" else
                 regMem                      when muxReg = "11";

    
    
end controle_arch;