library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;



entity SPI_CLK_GEN is
generic(
    CLOCK_DIV           : integer := (20);
    CLK_TO_CS_MARGIN    : integer := (2)
);
port (
    i_SystemClk         : in std_logic;
    i_rst               : in std_logic;
    i_generateClk       : in std_logic;
    o_spi_sck           : out std_logic;
    o_spi_csn           : out std_logic;
    o_spi_sck_posedge   : out std_logic;
    o_spi_sck_negedge   : out std_logic;
    o_spi_sck_pre       : out std_logic;
    o_spi_sck_stb       : out std_logic
);
end SPI_CLK_GEN ;

architecture Behavioral of SPI_CLK_GEN is

    -------------------- Constant Declarations --------------------------------------
    constant c_CLOCK_POLARITY  : std_logic := '0';
    -------------------- Constant Declarations --------------------------------------

    -------------------- Signal Declarations --------------------------------------
    signal s_ClkDividerCounter : std_logic_vector(7 downto 0) := (others => '1');
    signal s_clk_posedge : std_logic := '0';    
    signal s_clk_negedge : std_logic := '0';    
    signal s_clk_pre : std_logic := '0';    
    signal s_clk_stb : std_logic := '0';
    signal s_spi_sck : std_logic := c_CLOCK_POLARITY;
    signal s_spi_csn : std_logic := '1';

    
    -------------------- Signal Declarations --------------------------------------

    -------------------- Controller Sections --------------------------------------
    type state_QSPI_GENERATE_CLOCK is ( 
        QSPI_GENERATE_CLOCK_Idle, 
        QSPI_GENERATE_CLOCK_TOGGLE,
        QSPI_GENERATE_CLOCK_DELAY
    );
    signal s_GenerateClk_ps : state_QSPI_GENERATE_CLOCK := QSPI_GENERATE_CLOCK_Idle; 
    -------------------- Controller Sections --------------------------------------

    -------------------- Debug Declarations --------------------------------------
    attribute MARK_DEBUG : string;
--    attribute MARK_DEBUG of  : signal is "TRUE";
    -------------------- Debug Declarations --------------------------------------

    -------------------- Attributes Declarations --------------------------------------
    -------------------- Attributes Declarations --------------------------------------


begin
    o_spi_sck <= s_spi_sck;
    o_spi_csn <= s_spi_csn;
    o_spi_sck_posedge <= s_clk_posedge;
    o_spi_sck_negedge <= s_clk_negedge;
    o_spi_sck_pre <= s_clk_pre;
    o_spi_sck_stb <= s_clk_stb;

    process (i_SystemClk)begin
        if rising_edge(i_SystemClk) then
            s_spi_csn <= s_spi_csn;
            if( i_generateClk = '1' )then
                s_spi_csn <= '0';
            elsif( (s_GenerateClk_ps = QSPI_GENERATE_CLOCK_Idle or s_GenerateClk_ps = QSPI_GENERATE_CLOCK_DELAY) )then
                s_spi_csn <= '1';
            end if;

            if( i_rst = '1' )then
                s_spi_csn <= '1';
            end if;
        end if;
    end process;

    process (i_SystemClk)begin
        if rising_edge(i_SystemClk) then
            s_spi_sck <= s_spi_sck;
            if( s_GenerateClk_ps = QSPI_GENERATE_CLOCK_TOGGLE and s_clk_negedge = '1' )then
                s_spi_sck <= '0';
            elsif( s_clk_posedge = '1' )then
                s_spi_sck <= '1';
            end if;

            if( i_rst = '1' )then
                s_spi_sck <= c_CLOCK_POLARITY;
            end if;
        end if;
    end process;

    process (i_SystemClk)begin
        if rising_edge(i_SystemClk) then
            s_clk_negedge <= '0';
            s_clk_posedge <= '0';
            s_clk_pre <= '0';
            s_clk_stb <= '0';
            if( unsigned(s_ClkDividerCounter) = to_unsigned(CLOCK_DIV/2, s_ClkDividerCounter'length) )then
                s_clk_negedge <= '1';
                s_clk_stb <= '1';
            elsif( unsigned(s_ClkDividerCounter) = to_unsigned(0, s_ClkDividerCounter'length) )then
                s_clk_posedge <= '1';
            elsif( unsigned(s_ClkDividerCounter) = to_unsigned(CLOCK_DIV/2+1, s_ClkDividerCounter'length) )then
                s_clk_pre <= '1';
            end if;

            if( i_rst = '1' )then
                s_clk_negedge <= '0';
                s_clk_posedge <= '0';
                s_clk_pre <= '0';
            end if;
        end if;
    end process;

    process (i_SystemClk)begin
        if rising_edge(i_SystemClk) then
            s_GenerateClk_ps <= s_GenerateClk_ps;
            s_ClkDividerCounter <= std_logic_vector(to_unsigned(CLOCK_DIV-1, s_ClkDividerCounter'length));            

            case s_GenerateClk_ps is
                when QSPI_GENERATE_CLOCK_Idle =>
                    if( i_generateClk = '1' )then
                        s_GenerateClk_ps <= QSPI_GENERATE_CLOCK_TOGGLE;
                        -- s_ClkDividerCounter <= std_logic_vector(to_unsigned(CLOCK_DIV/2 + CLOCK_DIV/8, s_ClkDividerCounter'length)); -- small different frame
                        s_ClkDividerCounter <= std_logic_vector(to_unsigned(CLK_TO_CS_MARGIN, s_ClkDividerCounter'length)); -- small different frame
                    end if;

                when QSPI_GENERATE_CLOCK_TOGGLE =>
                    s_ClkDividerCounter <= std_logic_vector( unsigned(s_ClkDividerCounter) - 1 );
                    if( unsigned(s_ClkDividerCounter) = 0 )then
                        s_ClkDividerCounter <= std_logic_vector(to_unsigned(CLOCK_DIV-1, s_ClkDividerCounter'length));
                    end if;
                    -- if( i_generateClk = '0' and (unsigned( s_ClkDividerCounter ) = 1) )then -- equal to one to bypass last posedge
                    if( i_generateClk = '0' and (unsigned( s_ClkDividerCounter ) = CLOCK_DIV/4 + CLK_TO_CS_MARGIN) )then -- equal to one to bypass last posedge
                        s_GenerateClk_ps <= QSPI_GENERATE_CLOCK_Idle;
                        -- s_GenerateClk_ps <= QSPI_GENERATE_CLOCK_DELAY;
                        -- s_ClkDividerCounter <= std_logic_vector(to_unsigned(CLK_TO_CS_MARGIN, s_ClkDividerCounter'length));
                    end if;

                when QSPI_GENERATE_CLOCK_DELAY =>
                    s_ClkDividerCounter <= std_logic_vector( unsigned(s_ClkDividerCounter) - 1 );
                    -- if( unsigned(s_ClkDividerCounter) = to_unsigned(CLOCK_DIV/2-CLOCK_DIV/8-1, s_ClkDividerCounter'length) )then
                    --     s_GenerateClk_ps <= QSPI_GENERATE_CLOCK_Idle;
                    -- end if;
                    if( unsigned(s_ClkDividerCounter) = 2 )then -- equal to one to bypass last posedge
                        s_GenerateClk_ps <= QSPI_GENERATE_CLOCK_Idle;
                    end if;

                when others =>
            end case;

            if( i_rst = '1' )then
                s_ClkDividerCounter <= std_logic_vector(to_unsigned(CLOCK_DIV-1, 8));
                s_GenerateClk_ps <= QSPI_GENERATE_CLOCK_Idle;
            end if;
        end if;
    end process;


end architecture ; -- Behavioral
