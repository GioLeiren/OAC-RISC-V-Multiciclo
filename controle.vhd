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
        we : in std_logic;
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

    -- Sinais do Controle
    signal escrevePC :std_logic := '0';
    signal escrevePCCond :std_logic := '0';
    signal IouD :std_logic := '0'; 
    signal escreveMem :std_logic;
    signal leMem :std_logic := '1';
    signal escreveIR :std_logic := '1';
    signal OrigPC :std_logic := '0';
    signal ALUOp :std_logic_vector(1 downto 0);
    signal OrigAULA :std_logic_vector(1 downto 0);
    signal OrigBULA :std_logic_vector(1 downto 0);
    signal escrevePCB :std_logic := '1';
    signal escreveReg :std_logic := '0';
    signal Mem2Reg :std_logic_vector(1 downto 0);

    -- PC
    signal pc :std_logic_vector(31 downto 0) := 32x"0";

    -- Sinais para o RI
    signal ri :std_logic_vector(31 downto 0);

    -- Sinais para o PcBack
    signal pcBack :std_logic_vector(31 downto 0);

    -- Sinais para a memória
    signal memAddress :std_logic_vector(11 downto 0);
    signal dataIn :std_logic_vector(31 downto 0);
    signal dataOut :std_logic_vector(31 downto 0);

    -- Sinais para a ULA
    signal ulaOpcode :std_logic_vector(3 downto 0);
    signal entradaAUla :std_logic_vector(31 downto 0);
    signal entradaBUla :std_logic_vector(31 downto 0);
    signal saidaUla :std_logic_vector(31 downto 0);

    -- Sinais para Banco de Registradores
    signal rs1Reg :std_logic_vector(4 downto 0);
    signal rs2Reg :std_logic_vector(4 downto 0);
    signal rdReg :std_logic_vector(4 downto 0);
    signal dataInReg :std_logic_vector(31 downto 0);
    signal regSaidaA :std_logic_vector(31 downto 0);
    signal regSaidaB :std_logic_vector(31 downto 0);

    -- Sinais para o gerador de imediatos
    signal imediato :signed(31 downto 0);
    
    -- Sinais para Controle da ULA
    signal funct3 :std_logic_vector(2 downto 0);
    signal funct7 :std_logic_vector(6 downto 0);
    
    --Outros sinais controle
    signal estado :std_logic_vector(2 downto 0) := "000";


begin
    clk <= clock;

    memoria: mem_rv port map (clock => clk, 
                            we => escreveMem, 
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
            -- Memoria de dados e instruções foi inicializada corretamente 
            if estado_atual = Inicio and memReady = '1' then
                estado_atual <= Fetch;
            else
            -- Memoria ainda nao foi inicializada
                estado_atual <= prox_estado;
            end if;
        end if;
        
    end process;

    comb_process: process (estado_atual)
    begin
        -- Seta os sinais necessários para a fase de inicialização
        if estado_atual = Inicio then
            escreveMem <= '1';

        elsif estado_atual = Fetch then
            
            -- Caso tenha ocorrido uma instrução de branch, atualizar PC
            if (branchEq = '1' and zeroUla = '1') or (branchNe = '1' and zeroUla = '0') or (jump = '1') then
                pc <= regNextPc;
            end if;

            -- Seta os sinais necessários para a fase de Fetch
            IouD <= '0';        -- PC como entrada do MUX da memória
            leMem <= '1';       -- Enable de leitura da memória de dados e instruções
            escreveIR <= '1';
            OrigAULA <= "10";
            OrigBULA <= "01";
            ALUOp <= "00";
            OrigPC <= '0';
            escrevePC <= '1';
            escrevePCB <= '1';
            prox_estado <= Decode;

        elsif estado_atual = Decode then

            OrigAULA <= "00";
            OrigBULA <= "11";
            
            branchEq <= '0';
            branchNe <= '0';
            jump <= '0';
            writeRi <= '1';
            pc <= regNextPc;
            writePc <= '0';
            writePcb <= '0';
            muxUla1 <= "00";
            muxUla2 <= "11";
            ulaOpcode <= 4x"0";
            writeRegUla <= '1';
            prox_estado <= Execute;

        elsif estado_atual = Execute then
            writeMem <= '0';
            readMem <= '0';
            writeRegUla <= '1';
            writeRi <= '0';

            if Opcode = 7x"17" then  -- AUIPC
                prox_estado <= Memory;
                muxUla1 <= "00";
                muxUla2 <= "10";
                ulaOpcode <= 4x"0";

            elsif Opcode = 7x"63" then  -- Branch
                prox_estado <= Fetch;
                muxUla1 <= "10";
                muxUla2 <= "00";
                ulaOpcode <= 4x"1";
                writeRegUla <= '0';
                muxSaidaUla <= '1';
                writePc <= '1';

                if funct3 = "000" then
                    branchEq <= '1';
                elsif funct3 = "001" then
                    branchNe <= '1';
                end if;

            elsif Opcode = 7x"13" then  -- RI_Type
                prox_estado <= Memory;
                muxUla1 <= "10";
                muxUla2 <= "10";

                if funct3 = "000" then  -- ADDi
                    ulaOpcode <= 4x"0";
                elsif funct3 = "100" then  -- XORi
                    ulaOpcode <= "0100";
                elsif funct3 = "110" then  -- ORi
                    ulaOpcode <= "0011";
                elsif funct3 = "111" then  -- ANDi
                    ulaOpcode <= "0010";
                end if;

            elsif Opcode = 7x"6F" then  -- JAL
                prox_estado <= Fetch;
                muxSaidaUla <= '1';
                writePc <= '1';
                writeReg <= '1';
                muxReg <= "01";
                jump <= '1';

            elsif Opcode = 7x"67" then  -- JALR
                prox_estado <= Fetch;
                muxUla1 <= "10";
                muxUla2 <= "10";
                muxSaidaUla <= '1';
                writePc <= '1';
                writeReg <= '1';
                muxReg <= "01";
                jump <= '1';

            elsif Opcode = 7x"33" then  -- R_Type
                prox_estado <= Memory;
                muxUla1 <= "10";
                muxUla2 <= "00";

                if funct3 = "000" then
                    if funct7 = 7x"0" then
                        ulaOpcode <= 4x"0";  -- Soma
                    elsif funct7 = 7x"20" then
                        ulaOpcode <= 4x"1";  -- Subtração
                    end if;
                elsif funct3 = "111" then
                    ulaOpcode <= "0010";  -- AND
                elsif funct3 = "110" then
                    ulaOpcode <= "0011";  -- OR
                elsif funct3 = "100" then
                    ulaOpcode <= "0100";  -- XOR
                elsif funct3 = "010" then
                    ulaOpcode <= "1000";  -- SLT
                end if;

            elsif Opcode = 7x"23" or Opcode = 7x"3" then  -- SW | LW
                prox_estado <= Memory;
                muxUla1 <= "10";
                muxUla2 <= "10";
                ulaOpcode <= 4x"0";

            elsif Opcode = 7x"37" then  -- LUI
                prox_estado <= Fetch;
                muxReg <= "10";
                writeReg <= '1';

            end if;

        elsif estado_atual = Memory then

            if Opcode = 7x"17" or Opcode = 7x"33" or Opcode = 7x"13" then  -- AUIPC | R_Type | RI_Type
                prox_estado <= Fetch;
                writeReg <= '1';
                muxReg <= "00";

            elsif Opcode = 7x"3" then  -- LW
                prox_estado <= WriteBack;
                readMem <= '1';
                muxAddress <= "10";

            elsif Opcode = 7x"23" then  -- SW
                prox_estado <= Fetch;
                muxData <= '0';
                muxAddress <= "10";
                writeMem <= '1';

            end if;

        elsif estado_atual = WriteBack then

            if Opcode = 7x"3" then  -- LW
                writeReg <= '1';
                muxReg <= "11";
            end if;

            prox_estado <= Fetch;

        end if;
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