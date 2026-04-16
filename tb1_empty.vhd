-- TB1: reset + empty list operations + basic START/DONE protocol

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.tb_utils_pkg.all;

entity project_tb_empty_cases is
end project_tb_empty_cases;


architecture project_tb_arch of project_tb_empty_cases is

    constant CLOCK_PERIOD : time := 20 ns;

    signal tb_clk           : std_logic := '0';
    signal tb_rst           : std_logic := '0';
    signal tb_start         : std_logic := '0';
    signal tb_done          : std_logic;
    signal tb_o_task_id     : std_logic_vector(5 downto 0);
    signal tb_task_priority : std_logic_vector(1 downto 0) := (others => '0');
    signal tb_op            : std_logic_vector(1 downto 0) := (others => '0');
    signal tb_i_task_id     : std_logic_vector(5 downto 0) := (others => '0');

    signal tb_o_mem_addr    : std_logic_vector(15 downto 0);
    signal tb_o_mem_data    : std_logic_vector(7 downto 0);
    signal tb_i_mem_data    : std_logic_vector(7 downto 0);
    signal tb_o_mem_we      : std_logic;
    signal tb_o_mem_en      : std_logic;

    signal exc_o_mem_addr   : std_logic_vector(15 downto 0);
    signal exc_o_mem_data   : std_logic_vector(7 downto 0);
    signal exc_o_mem_we     : std_logic;
    signal exc_o_mem_en     : std_logic;

    signal init_o_mem_addr  : std_logic_vector(15 downto 0) := (others => '0');
    signal init_o_mem_data  : std_logic_vector(7 downto 0)  := (others => '0');
    signal init_o_mem_we    : std_logic := '0';
    signal init_o_mem_en    : std_logic := '0';

    signal memory_control   : std_logic := '0';

    signal RAM : ram_type := (others => (others => '0'));


    component project_reti_logiche is
        port (
            i_clk           : in std_logic;
            i_rst           : in std_logic;

            i_start         : in std_logic;
            i_task_id       : in std_logic_vector(5 downto 0);
            i_task_priority : in std_logic_vector(1 downto 0);
            i_op            : in std_logic_vector(1 downto 0);

            o_done          : out std_logic;
            o_task_id       : out std_logic_vector(5 downto 0);

            o_mem_addr      : out std_logic_vector(15 downto 0);
            i_mem_data      : in std_logic_vector(7 downto 0);
            o_mem_data      : out std_logic_vector(7 downto 0);
            o_mem_we        : out std_logic;
            o_mem_en        : out std_logic
        );
    end component;


begin

    --------------------------------------------------
    -- DUT
    --------------------------------------------------

    UUT : project_reti_logiche
    port map (
        i_clk           => tb_clk,
        i_rst           => tb_rst,
        i_start         => tb_start,
        i_task_id       => tb_i_task_id,
        i_task_priority => tb_task_priority,
        i_op            => tb_op,

        o_done          => tb_done,
        o_task_id       => tb_o_task_id,

        o_mem_addr      => exc_o_mem_addr,
        i_mem_data      => tb_i_mem_data,
        o_mem_data      => exc_o_mem_data,
        o_mem_we        => exc_o_mem_we,
        o_mem_en        => exc_o_mem_en
    );


    --------------------------------------------------
    -- clock generation
    --------------------------------------------------

    tb_clk <= not tb_clk after CLOCK_PERIOD / 2;


    --------------------------------------------------
    -- RAM model
    --------------------------------------------------

    MEM : process(tb_clk)
    begin
        if rising_edge(tb_clk) then
            if tb_o_mem_en = '1' then
                if tb_o_mem_we = '1' then
                    RAM(to_integer(unsigned(tb_o_mem_addr))) <= tb_o_mem_data after 1 ns;
                    tb_i_mem_data <= tb_o_mem_data after 1 ns;
                else
                    tb_i_mem_data <= RAM(to_integer(unsigned(tb_o_mem_addr))) after 1 ns;
                end if;
            end if;
        end if;
    end process;


    --------------------------------------------------
    -- memory signal swapper
    --------------------------------------------------

    memory_signal_swapper : process(
        memory_control,
        init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
        exc_o_mem_addr, exc_o_mem_data, exc_o_mem_en, exc_o_mem_we
    )
    begin
        -- This is necessary for the testbench to work: we swap the memory
        -- signals from the component to the testbench when needed.

        tb_o_mem_addr <= init_o_mem_addr;
        tb_o_mem_data <= init_o_mem_data;
        tb_o_mem_en   <= init_o_mem_en;
        tb_o_mem_we   <= init_o_mem_we;

        if memory_control = '1' then
            tb_o_mem_addr <= exc_o_mem_addr;
            tb_o_mem_data <= exc_o_mem_data;
            tb_o_mem_en   <= exc_o_mem_en;
            tb_o_mem_we   <= exc_o_mem_we;
        end if;
    end process;


    --------------------------------------------------
    -- stimulus and checks
    --------------------------------------------------

    scenario : process
    begin
        --------------------------------------------------
        -- initial values
        --------------------------------------------------
        clear_inputs(tb_start, tb_op, tb_i_task_id, tb_task_priority);

        wait for 50 ns;

        --------------------------------------------------
        -- reset phase
        --------------------------------------------------
        tb_rst <= '1';
        wait for 100 ns;

        -- during reset / init phase the module may already have o_done = 1,
        -- or be in the middle of forcing RAM(0) to zero
        assert (tb_done = '1') or (tb_done = '0' and RAM(0) = x"00")
    report "TEST FAILED: invalid condition during/post reset"
    severity failure;

    tb_rst <= '0';
    memory_control <= '1';

    if tb_done = '1' then
        wait until falling_edge(tb_done);
    end if;

    assert RAM(0) = x"00"
        report "TEST FAILED: RAM(0) /= 0 after post-reset initialization"
        severity failure;

        wait until falling_edge(tb_clk);

        --------------------------------------------------
        -- STEP 1: OP=01 on empty list
        --------------------------------------------------
        run_operation(
            tb_clk,
            tb_start,
            tb_op,
            tb_i_task_id,
            tb_task_priority,
            tb_done,
            RAM(0),
            tb_o_task_id,
            "01",
            "000000",
            "00",
            0,
            "000000"
        );

        report "STEP 1 OK: OP=01 on an empty list.";

        --------------------------------------------------
        -- STEP 2: OP=00 on empty list
        --------------------------------------------------
        run_operation(
            tb_clk,
            tb_start,
            tb_op,
            tb_i_task_id,
            tb_task_priority,
            tb_done,
            RAM(0),
            tb_o_task_id,
            "00",
            "000000",
            "00",
            0
        );

        report "STEP 2 OK: OP=00 on an empty list.";

        --------------------------------------------------
        -- STEP 3: OP=11 on empty list
        --------------------------------------------------
        run_operation(
            tb_clk,
            tb_start,
            tb_op,
            tb_i_task_id,
            tb_task_priority,
            tb_done,
            RAM(0),
            tb_o_task_id,
            "11",
            "000000",
            "00",
            0
        );

        report "STEP 3 OK: OP=11 on an empty list.";

        --------------------------------------------------
        -- STEP 4: repeat empty pop after previous operations
        --------------------------------------------------
        run_operation(
            tb_clk,
            tb_start,
            tb_op,
            tb_i_task_id,
            tb_task_priority,
            tb_done,
            RAM(0),
            tb_o_task_id,
            "01",
            "000000",
            "00",
            0,
            "000000"
        );

        report "STEP 4 OK: second OP=01 on an empty list.";

        --------------------------------------------------
        -- final result
        --------------------------------------------------
        report "=========================================";
        assert false
            report "Simulation Ended! TESTBENCH 1 PASSED (reset + empty cases + handshake base)"
            severity failure;
    end process;

end architecture;
