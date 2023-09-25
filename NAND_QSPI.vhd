library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;



entity NAND_QSPI is
generic(
    CLOCK_DIV           : integer := (20);
    MAX_COMMAND_BYTES   : integer := (4)
);
port (
    i_SystemClk         : in std_logic;
    i_rst               : in std_logic;
    i_ReadRequest       : in std_logic;
    i_WriteRequest      : in std_logic;
    o_OperationBusy     : out std_logic;
    o_OperationDone     : out std_logic;
    --
    i_SPI_Mode          : in std_logic;
    i_HasDummyByte      : in std_logic;
    i_Command_Data      : in std_logic_vector(MAX_COMMAND_BYTES*8-1 downto 0);
    i_Command_size      : in std_logic_vector( 3 downto 0 );
    i_payload_size      : in std_logic_vector( 15 downto 0 );
    o_payload_rq        : out std_logic;
    i_payload_byte      : in std_logic_vector( 7 downto 0 );
    o_payload_data      : out std_logic_vector( 15 downto 0 );
    o_payload_valid     : out std_logic;
    --
    o_qspi_mode         : out std_logic_vector( 1 downto 0 );
    o_qspi_sck          : out std_logic;
    o_qspi_csn          : out std_logic;
    o_qspi_data         : out std_logic_vector( 3 downto 0 );
    i_qspi_data         : in std_logic_vector( 3 downto 0 )   
);
end NAND_QSPI ;

architecture Behavioral of NAND_QSPI is

    -------------------- Constant Declarations --------------------------------------
    constant c_NORMAL_SPI : std_logic_vector(1 downto 0) := "00";
    constant c_QUAD_WRITE : std_logic_vector(1 downto 0) := "10";
    constant c_QUAD_READ  : std_logic_vector(1 downto 0) := "11";
    -------------------- Constant Declarations --------------------------------------

    -------------------- Signal Declarations --------------------------------------
    signal s_qspi_sck : std_logic;
    signal s_qspi_csn : std_logic;
    signal s_generateClk : std_logic := '0';
    signal s_clk_posedge : std_logic := '0';    
    signal s_clk_posedge_r : std_logic := '0';    
    signal s_clk_negedge : std_logic := '0';    
    signal s_clk_pre : std_logic := '0';    
    signal s_clk_stb : std_logic := '0';    
    --
    signal s_OperationBusy : std_logic := '0';
    signal s_OperationDone : std_logic := '0';
    signal s_payload_data : std_logic_vector(15 downto 0) := (others => '0');
    signal s_payload_valid : std_logic := ('0');
    signal s_payload_rq : std_logic := '0';

    signal s_qspi_mode : std_logic_vector(1 downto 0) := (others => '0');
    signal s_qspi_data : std_logic_vector(3 downto 0) := (others => '0');
        
    signal s_Command_Data  : std_logic_vector(MAX_COMMAND_BYTES*8-1 downto 0) := (others => '0');
    signal s_spiclk_cnt : std_logic_vector(15+3 downto 0) := (others => '0');
    signal s_payload_cnt : std_logic_vector(15+3 downto 0) := (others => '0');
    signal s_command_cnt : std_logic_vector(3+3 downto 0) := (others => '0');
    signal s_SPI_Mode : std_logic := ('0');
    signal s_HasDummyByte : std_logic := ('0');
    
    signal s_MaxReadTransaction     : std_logic_vector(18 downto 0) := (others => '0');
    signal s_MaxWriteTransaction    : std_logic_vector(18 downto 0) := (others => '0');
    signal s_ReadTransactionCnt     : unsigned(18 downto 0) := (others => '0');
    signal s_WriteTransactionCnt    : unsigned(18 downto 0) := (others => '0');

        -- for visual debug purposes only
        signal s_qspi_PinType : std_logic_vector(3 downto 0) := (others => '0');

    -------------------- Signal Declarations --------------------------------------

    -------------------- Controller Sections --------------------------------------
    type state_QSPI_Control is ( 
        QSPI_Control_Idle,
        QSPI_Control_SendCommand,
        QSPI_Control_ReceiveData,
        QSPI_Control_TransmitData,
        QSPI_Control_delay
    );
    signal s_QSPI_control_ps : state_QSPI_Control := QSPI_Control_Idle; 
    signal s_QSPI_control_ns : state_QSPI_Control := QSPI_Control_Idle; 

    -------------------- Controller Sections --------------------------------------

    -------------------- Debug Declarations --------------------------------------
    attribute MARK_DEBUG : string;
--    attribute MARK_DEBUG of  : signal is "TRUE";
    -------------------- Debug Declarations --------------------------------------

    -------------------- Attributes Declarations --------------------------------------
    -------------------- Attributes Declarations --------------------------------------


begin
    ------------
    o_qspi_mode <= s_qspi_mode;
    o_qspi_sck <= s_qspi_sck;
    o_qspi_csn <= s_qspi_csn;

    o_OperationBusy <= s_OperationBusy;
    o_OperationDone <= s_OperationDone;
    process (s_clk_pre, s_payload_rq , s_QSPI_control_ps, s_QSPI_control_ns, s_command_cnt)begin
        
        if( s_QSPI_control_ps = QSPI_Control_SendCommand and s_QSPI_control_ns = QSPI_Control_TransmitData and unsigned(s_command_cnt) = 0 )then
            o_payload_rq <= s_clk_pre;
        else
            o_payload_rq <= s_payload_rq;            
        end if;

    end process;

    o_payload_data <= s_payload_data;
    o_payload_valid <= s_payload_valid;

    process (s_qspi_mode, s_Command_Data, s_qspi_data, s_QSPI_control_ps)begin
        o_qspi_data(3 downto 2) <= (others => '1');
        o_qspi_data(1 downto 0) <= (others => '0');
        s_qspi_PinType(3 downto 2) <= "11";
        s_qspi_PinType(0) <= '1';
        s_qspi_PinType(1) <= 'Z';

        case s_qspi_mode is
            when c_NORMAL_SPI =>
                o_qspi_data(3 downto 2) <= (others => '1');
                o_qspi_data(1 downto 1) <= (others => '0');
                s_qspi_PinType(3 downto 2) <= "11";
                s_qspi_PinType(0) <= '1';
                s_qspi_PinType(1) <= 'Z';
                
                if( s_QSPI_control_ps = QSPI_Control_SendCommand )then
                    o_qspi_data(0) <= s_Command_Data( s_Command_Data'length-1 );
                elsif( s_QSPI_control_ps = QSPI_Control_TransmitData )then
                    o_qspi_data(0) <= s_qspi_data(0);
                else
                    o_qspi_data(0) <= '0';
                end if;
    
            when c_QUAD_WRITE =>
                o_qspi_data(3 downto 0) <= s_qspi_data( 3 downto 0 );
                s_qspi_PinType(3 downto 2) <= "11";
                s_qspi_PinType(0) <= '1';
                s_qspi_PinType(1) <= '1';

            when c_QUAD_READ  =>
                o_qspi_data(3 downto 0) <= (others => '0');
                s_qspi_PinType(3 downto 2) <= "ZZ";
                s_qspi_PinType(0) <= 'Z';
                s_qspi_PinType(1) <= 'Z';

            when others =>
                null;
        end case;
    end process;
    ------------
    process (i_SystemClk)begin
        if rising_edge(i_SystemClk) then
            s_OperationBusy <= s_OperationBusy;
            s_OperationDone <= '0';
            s_payload_valid <= '0';
            s_payload_data <= s_payload_data;
            s_qspi_mode <= s_qspi_mode;
            s_payload_rq <= '0';
            s_qspi_data <= (others => '0');

            s_clk_posedge_r <= s_clk_posedge;
            s_QSPI_control_ps <= s_QSPI_control_ps;
            s_payload_cnt <= s_payload_cnt;
            s_command_cnt <= s_command_cnt;
            s_generateClk <= s_generateClk;
            s_SPI_Mode <= s_SPI_Mode;
            s_HasDummyByte <= s_HasDummyByte;

            s_MaxReadTransaction <= s_MaxReadTransaction;
            s_MaxWriteTransaction <= s_MaxWriteTransaction;
            s_ReadTransactionCnt <= s_ReadTransactionCnt;
            s_WriteTransactionCnt <= s_WriteTransactionCnt;

            case s_QSPI_control_ps is
                when QSPI_Control_Idle =>
                    s_ReadTransactionCnt <= (others => '0');
                    s_WriteTransactionCnt <= (others => '0');
                    s_OperationBusy <= '0';
                    s_SPI_Mode <= i_SPI_Mode;
                    s_HasDummyByte <= i_HasDummyByte;
                    s_qspi_mode <= c_NORMAL_SPI;
                    s_payload_data <= (others => '0');
                    if( i_ReadRequest = '1' )then
                        s_QSPI_control_ps <= QSPI_Control_SendCommand;
                        s_QSPI_control_ns <= QSPI_Control_ReceiveData;
                        s_command_cnt <= std_logic_vector( unsigned(i_Command_size & "000") - 1); -- each bit one cycle
                        s_Command_Data <= i_Command_Data;
                        s_OperationBusy <= '1';
                        s_generateClk <= '1';
                        if( i_SPI_Mode = '1' )then
                            s_MaxReadTransaction <= std_logic_vector( unsigned(i_payload_size & "000"));
                        else
                            s_MaxReadTransaction <= std_logic_vector( unsigned( "00" & i_payload_size & '0'));
                        end if;
                        if( unsigned(i_payload_size) = 0 )then
                            s_QSPI_control_ns <= QSPI_Control_delay;
                        end if;
                    elsif( i_WriteRequest = '1' )then
                        s_QSPI_control_ps <= QSPI_Control_SendCommand;
                        s_QSPI_control_ns <= QSPI_Control_TransmitData;
                        s_command_cnt <= std_logic_vector( unsigned(i_Command_size & "000") - 1); -- each bit one cycle
                        s_Command_Data <= i_Command_Data;
                        s_OperationBusy <= '1';
                        s_generateClk <= '1';
                        if( i_SPI_Mode = '1' )then
                            s_MaxWriteTransaction <= std_logic_vector( unsigned(i_payload_size & "000"));
                        else
                            s_MaxWriteTransaction <= std_logic_vector( unsigned( "00" & i_payload_size & '0'));
                        end if;
                        if( unsigned(i_payload_size) = 0 )then
                            s_QSPI_control_ns <= QSPI_Control_delay;
                        end if;
                    else
                        s_QSPI_control_ps <= QSPI_Control_Idle;
                        s_QSPI_control_ns <= QSPI_Control_Idle;
                    end if;



                when QSPI_Control_SendCommand =>
                    if( s_clk_stb = '1' )then
                        s_Command_Data <= s_Command_Data( s_Command_Data'length-2 downto 0 ) & '0';
                        s_command_cnt <= std_logic_vector(unsigned(s_command_cnt) - 1);
                    end if;
                    if( unsigned(s_command_cnt) = 0 and s_clk_pre = '1' )then
                        s_QSPI_control_ps <= s_QSPI_control_ns;
                        if( s_QSPI_control_ns = QSPI_Control_TransmitData )then
                            -- s_payload_rq <= '1';
                        end if;
                    end if;
                    if( ( unsigned(s_command_cnt) = 0 and s_clk_pre = '1' ) or ( unsigned(s_command_cnt) < 8 and s_HasDummyByte = '1' and s_clk_posedge = '1') )then
                        if( s_SPI_Mode = '1' )then
                            s_qspi_mode <= c_NORMAL_SPI;
                        elsif( s_QSPI_control_ns = QSPI_Control_TransmitData )then
                            s_qspi_mode <= c_QUAD_WRITE;
                        elsif( s_QSPI_control_ns = QSPI_Control_ReceiveData )then
                            s_qspi_mode <= c_QUAD_READ;
                        end if;
                    end if;


                when QSPI_Control_ReceiveData =>
                    -- if( s_clk_stb = '1' )then
                    if( s_clk_posedge_r = '1' )then
                        s_ReadTransactionCnt <= s_ReadTransactionCnt + 1;
                        if( s_SPI_Mode = '0' )then
                            s_payload_data <= s_payload_data(s_payload_data'length-5 downto 0) & i_qspi_data;
                        else
                            s_payload_data <= s_payload_data(s_payload_data'length-2 downto 0) & i_qspi_data(1);
                        end if;
                    end if;
                    if( s_clk_stb = '1' )then
                        if( s_SPI_Mode = '0' )then
                            if( s_ReadTransactionCnt(1 downto 0) = "00" and s_ReadTransactionCnt(s_ReadTransactionCnt'length-1 downto 2) /= 0 )then
                                s_payload_valid <= '1';
                            end if;
                        else
                            if( s_ReadTransactionCnt(3 downto 0) = "0000" and s_ReadTransactionCnt(s_ReadTransactionCnt'length-1 downto 4) /= 0 )then
                                s_payload_valid <= '1';
                            end if;
                        end if;
                    end if;
                    if( s_ReadTransactionCnt = unsigned( s_MaxReadTransaction ) and s_clk_negedge = '1' )then
                        s_QSPI_control_ps <= QSPI_Control_delay;
                        s_payload_valid <= '1';
                    end if;

                when QSPI_Control_TransmitData =>
                    s_qspi_data <= s_qspi_data;

                    if( s_clk_stb = '1' )then
                        if( s_SPI_Mode = '0' )then
                            if( s_WriteTransactionCnt(0) = '1' )then -- first high half
                                s_qspi_data(3 downto 0) <= i_payload_byte( 3 downto 0 );
                            else
                                s_qspi_data(3 downto 0) <= i_payload_byte( 7 downto 4 );
                            end if;    
                        else
                            s_qspi_data(0) <= i_payload_byte( to_integer( 7 - unsigned(s_WriteTransactionCnt(2 downto 0) ) ) );
                        end if;
                    end if;

                    if(s_clk_posedge_r = '1')then
                        s_WriteTransactionCnt <= s_WriteTransactionCnt + 1;
                    end if;
                    if( s_clk_stb = '1' )then
                        if( s_SPI_Mode = '0' )then
                            if( s_WriteTransactionCnt(0) = '1' and ( unsigned(s_MaxWriteTransaction)-1 /= s_WriteTransactionCnt) )then
                                s_payload_rq <= '1';
                            end if;
                        else
                            if( ( unsigned(s_MaxWriteTransaction)-1 /= s_WriteTransactionCnt) and s_WriteTransactionCnt(2 downto 0) = "111" and s_WriteTransactionCnt(s_WriteTransactionCnt'length-1 downto 2) /= 0 )then
                                s_payload_rq <= '1';
                            end if;
                        end if;
                    end if;
                    if( ( unsigned(s_MaxWriteTransaction) =  s_WriteTransactionCnt) and s_clk_negedge = '1' )then
                        s_QSPI_control_ps <= QSPI_Control_delay;
                        s_payload_rq <= '0';
                    end if;

                when QSPI_Control_delay =>
                    s_generateClk <= '0';
                    if( s_qspi_csn = '1' )then
                        s_OperationDone <= '1';
                        s_QSPI_control_ps <= QSPI_Control_Idle;
                    end if;
            
                when others =>
                    null;
            end case;
        end if;
    end process;
    ----
    process (i_SystemClk)begin
        if rising_edge(i_SystemClk) then
            s_spiclk_cnt <= s_spiclk_cnt;
            if( s_qspi_csn = '1' )then
                s_spiclk_cnt <= (others => '0');
            elsif( s_clk_posedge = '1' )then
                s_spiclk_cnt <= std_logic_vector(unsigned(s_spiclk_cnt) + 1);
            end if;
        end if;
    end process;
    ----
    SPI_CLK_GEN_inst : entity work.SPI_CLK_GEN
    generic map(
        CLOCK_DIV           => CLOCK_DIV
    )
    port map(
        i_SystemClk         => i_SystemClk, -- : in std_logic;
        i_rst               => i_rst, -- : in std_logic;
        i_generateClk       => s_generateClk, -- : in std_logic;
        o_spi_sck           => s_qspi_sck, -- : out std_logic;
        o_spi_csn           => s_qspi_csn, -- : out std_logic;
        o_spi_sck_posedge   => s_clk_posedge, -- : out std_logic;
        o_spi_sck_negedge   => s_clk_negedge, -- : out std_logic;
        o_spi_sck_pre       => s_clk_pre, -- : out std_logic;
        o_spi_sck_stb       => s_clk_stb  -- : out std_logic
    );

end architecture ; -- Behavioral
