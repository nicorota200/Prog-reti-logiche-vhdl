-- TB4: age/decrement operation coverage

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.tb_utils_pkg.all;

entity project_tb_age is
end project_tb_age;


architecture project_tb_arch of project_tb_age is

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
        -- STEP 1: all tasks already at priority 3
        --------------------------------------------------
        memory_control <= '0';

        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            0, std_logic_vector(to_unsigned(4, 8))
        );
        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            1, encode_task(3, 3)
        );
        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            2, encode_task(9, 3)
        );
        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            3, encode_task(18, 3)
        );
        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            4, encode_task(27, 3)
        );

        memory_control <= '1';

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
            4
        );

        check_ram_count(RAM, 4, "STEP 1 count after age on all-priority-3 list");
        check_ram_value(RAM, 1, encode_task(3, 3),  "STEP 1 RAM(1) unchanged");
        check_ram_value(RAM, 2, encode_task(9, 3),  "STEP 1 RAM(2) unchanged");
        check_ram_value(RAM, 3, encode_task(18, 3), "STEP 1 RAM(3) unchanged");
        check_ram_value(RAM, 4, encode_task(27, 3), "STEP 1 RAM(4) unchanged");

        report "STEP 1 OK: age on fully saturated list leaves all tasks unchanged.";

        --------------------------------------------------
        -- STEP 2: mixed priorities, first age
        --------------------------------------------------
        memory_control <= '0';

        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            0, std_logic_vector(to_unsigned(6, 8))
        );
        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            1, encode_task(16, 0)
        );
        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            2, encode_task(22, 0)
        );
        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            3, encode_task(23, 0)
        );
        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            4, encode_task(21, 1)
        );
        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            5, encode_task(28, 2)
        );
        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            6, encode_task(4, 3)
        );

        memory_control <= '1';

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
            6
        );

        check_ram_count(RAM, 6, "STEP 2 count after first age on mixed list");
        check_ram_value(RAM, 1, encode_task(16, 1), "STEP 2 RAM(1)");
        check_ram_value(RAM, 2, encode_task(22, 1), "STEP 2 RAM(2)");
        check_ram_value(RAM, 3, encode_task(23, 1), "STEP 2 RAM(3)");
        check_ram_value(RAM, 4, encode_task(21, 2), "STEP 2 RAM(4)");
        check_ram_value(RAM, 5, encode_task(28, 3), "STEP 2 RAM(5)");
        check_ram_value(RAM, 6, encode_task(4, 3),  "STEP 2 RAM(6)");

        report "STEP 2 OK: mixed-priority age updates priorities with saturation and preserves order.";

        --------------------------------------------------
        -- STEP 3: second age on same list
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
            6
        );

        check_ram_count(RAM, 6, "STEP 3 count after second age");
        check_ram_value(RAM, 1, encode_task(16, 2), "STEP 3 RAM(1)");
        check_ram_value(RAM, 2, encode_task(22, 2), "STEP 3 RAM(2)");
        check_ram_value(RAM, 3, encode_task(23, 2), "STEP 3 RAM(3)");
        check_ram_value(RAM, 4, encode_task(21, 3), "STEP 3 RAM(4)");
        check_ram_value(RAM, 5, encode_task(28, 3), "STEP 3 RAM(5)");
        check_ram_value(RAM, 6, encode_task(4, 3),  "STEP 3 RAM(6)");

        report "STEP 3 OK: repeated age progresses priorities further without changing ordering.";

        --------------------------------------------------
        -- STEP 4: third age reaches full saturation
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
            6
        );

        check_ram_count(RAM, 6, "STEP 4 count after third age");
        check_ram_value(RAM, 1, encode_task(16, 3), "STEP 4 RAM(1)");
        check_ram_value(RAM, 2, encode_task(22, 3), "STEP 4 RAM(2)");
        check_ram_value(RAM, 3, encode_task(23, 3), "STEP 4 RAM(3)");
        check_ram_value(RAM, 4, encode_task(21, 3), "STEP 4 RAM(4)");
        check_ram_value(RAM, 5, encode_task(28, 3), "STEP 4 RAM(5)");
        check_ram_value(RAM, 6, encode_task(4, 3),  "STEP 4 RAM(6)");

        report "STEP 4 OK: repeated age reaches full saturation.";

        --------------------------------------------------
        -- STEP 5: age on fully saturated result
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
            6
        );

        check_ram_count(RAM, 6, "STEP 5 count after age on fully saturated list");
        check_ram_value(RAM, 1, encode_task(16, 3), "STEP 5 RAM(1) unchanged");
        check_ram_value(RAM, 2, encode_task(22, 3), "STEP 5 RAM(2) unchanged");
        check_ram_value(RAM, 3, encode_task(23, 3), "STEP 5 RAM(3) unchanged");
        check_ram_value(RAM, 4, encode_task(21, 3), "STEP 5 RAM(4) unchanged");
        check_ram_value(RAM, 5, encode_task(28, 3), "STEP 5 RAM(5) unchanged");
        check_ram_value(RAM, 6, encode_task(4, 3),  "STEP 5 RAM(6) unchanged");

        report "STEP 5 OK: further age after full saturation leaves the list unchanged.";

        --------------------------------------------------
        -- STEP 6: explicit multi-element merge of old priority-2
        -- block with old priority-3 block
        --------------------------------------------------
        memory_control <= '0';

        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            0, std_logic_vector(to_unsigned(6, 8))
        );
        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            1, encode_task(10, 1)
        );
        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            2, encode_task(11, 2)
        );
        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            3, encode_task(12, 2)
        );
        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            4, encode_task(13, 3)
        );
        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            5, encode_task(14, 3)
        );
        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            6, encode_task(15, 3)
        );

        memory_control <= '1';

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
            6
        );

        check_ram_count(RAM, 6, "STEP 6 count after explicit 2->3 merge case");
        check_ram_value(RAM, 1, encode_task(10, 2), "STEP 6 RAM(1)");
        check_ram_value(RAM, 2, encode_task(11, 3), "STEP 6 first former-priority-2 task");
        check_ram_value(RAM, 3, encode_task(12, 3), "STEP 6 second former-priority-2 task");
        check_ram_value(RAM, 4, encode_task(13, 3), "STEP 6 first old-priority-3 task");
        check_ram_value(RAM, 5, encode_task(14, 3), "STEP 6 second old-priority-3 task");
        check_ram_value(RAM, 6, encode_task(15, 3), "STEP 6 third old-priority-3 task");

        report "STEP 6 OK: explicit multi-element merge at priority 3 preserves concatenation order.";
        
        --------------------------------------------------
        -- final result
        --------------------------------------------------
        report "=========================================";
        assert false
            report "Simulation Ended! TESTBENCH 4 PASSED (age cases)"
            severity failure;
    end process;

end architecture;