library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package tb_utils_pkg is

    --------------------------------------------------
    -- common RAM type
    --------------------------------------------------
    type ram_type is array (65535 downto 0) of std_logic_vector(7 downto 0);

    
    --------------------------------------------------
    -- task encoding helpers
    --------------------------------------------------
    function encode_task(
        task_id  : integer;
        priority : integer
    ) return std_logic_vector;

    function encode_task(
        task_id  : std_logic_vector(5 downto 0);
        priority : std_logic_vector(1 downto 0)
    ) return std_logic_vector;


    --------------------------------------------------
    -- input reset helper
    --------------------------------------------------
    procedure clear_inputs(
        signal start_sig : out std_logic;
        signal op_sig    : out std_logic_vector(1 downto 0);
        signal id_sig    : out std_logic_vector(5 downto 0);
        signal prio_sig  : out std_logic_vector(1 downto 0)
    );


    --------------------------------------------------
    -- RAM check helpers
    --------------------------------------------------
    procedure check_ram_value(
        signal ram_sig        : in ram_type;
        constant addr         : in integer;
        constant expected     : in std_logic_vector(7 downto 0);
        constant message_text : in string
    );


    procedure check_ram_count(
        signal ram_sig        : in ram_type;
        constant expected     : in integer;
        constant message_text : in string
    );

    
    --------------------------------------------------
    -- RAM preload helper
    --------------------------------------------------
    procedure preload_ram_value(
        signal clk        : in  std_logic;
        signal addr_sig   : out std_logic_vector(15 downto 0);
        signal data_sig   : out std_logic_vector(7 downto 0);
        signal en_sig     : out std_logic;
        signal we_sig     : out std_logic;
        constant addr     : in  integer;
        constant value    : in  std_logic_vector(7 downto 0)
    );

    
    --------------------------------------------------
    -- common operation runner
    --------------------------------------------------
    procedure run_operation (
        signal clk          : in  std_logic;
        signal start_sig    : out std_logic;
        signal op_sig       : out std_logic_vector(1 downto 0);
        signal id_sig       : out std_logic_vector(5 downto 0);
        signal prio_sig     : out std_logic_vector(1 downto 0);
        signal done_sig     : in  std_logic;
        signal count_sig    : in  std_logic_vector(7 downto 0);
        signal task_out_sig : in  std_logic_vector(5 downto 0);
        constant op_val     : in  std_logic_vector(1 downto 0);
        constant id_val     : in  std_logic_vector(5 downto 0);
        constant prio_val   : in  std_logic_vector(1 downto 0);
        constant count_val  : in  integer := -1;
        constant popped_id  : in  std_logic_vector(5 downto 0) := (others => '0')
    );

end package;


package body tb_utils_pkg is

    --------------------------------------------------
    -- shared operation counter for logging
    --------------------------------------------------
    shared variable op_number : integer := 0;

   
    --------------------------------------------------
    -- encode task from integers
    --------------------------------------------------
    function encode_task(
        task_id  : integer;
        priority : integer
    ) return std_logic_vector is
        variable encoded : unsigned(7 downto 0);
    begin
        encoded := shift_left(to_unsigned(task_id, 8), 2) or to_unsigned(priority, 8);
        return std_logic_vector(encoded);
    end function;

   
    --------------------------------------------------
    -- encode task from vectors
    --------------------------------------------------
    function encode_task(
        task_id  : std_logic_vector(5 downto 0);
        priority : std_logic_vector(1 downto 0)
    ) return std_logic_vector is
        variable encoded : std_logic_vector(7 downto 0);
    begin
        encoded := task_id & priority;
        return encoded;
    end function;

   
    --------------------------------------------------
    -- clear command inputs
    --------------------------------------------------
    procedure clear_inputs(
        signal start_sig : out std_logic;
        signal op_sig    : out std_logic_vector(1 downto 0);
        signal id_sig    : out std_logic_vector(5 downto 0);
        signal prio_sig  : out std_logic_vector(1 downto 0)
    ) is
    begin
        start_sig <= '0';
        op_sig    <= (others => '0');
        id_sig    <= (others => '0');
        prio_sig  <= (others => '0');
    end procedure;

   
    --------------------------------------------------
    -- check one RAM location
    --------------------------------------------------
    procedure check_ram_value(
        signal ram_sig        : in ram_type;
        constant addr         : in integer;
        constant expected     : in std_logic_vector(7 downto 0);
        constant message_text : in string
    ) is
    begin
        assert ram_sig(addr) = expected
            report "TEST FAILED: " & message_text &
                   " @ RAM(" & integer'image(addr) & ")" &
                   " expected=" & integer'image(to_integer(unsigned(expected))) &
                   " actual=" & integer'image(to_integer(unsigned(ram_sig(addr))))
            severity failure;
    end procedure;

   
    --------------------------------------------------
    -- check RAM(0) as task count
    --------------------------------------------------
    procedure check_ram_count(
        signal ram_sig        : in ram_type;
        constant expected     : in integer;
        constant message_text : in string
    ) is
    begin
        assert to_integer(unsigned(ram_sig(0))) = expected
            report "TEST FAILED: " & message_text &
                   " @ RAM(0) expected=" & integer'image(expected) &
                   " actual=" & integer'image(to_integer(unsigned(ram_sig(0))))
            severity failure;
    end procedure;

   
    --------------------------------------------------
    -- preload one RAM location through init interface
    --------------------------------------------------
    procedure preload_ram_value(
        signal clk        : in  std_logic;
        signal addr_sig   : out std_logic_vector(15 downto 0);
        signal data_sig   : out std_logic_vector(7 downto 0);
        signal en_sig     : out std_logic;
        signal we_sig     : out std_logic;
        constant addr     : in  integer;
        constant value    : in  std_logic_vector(7 downto 0)
    ) is
    begin
        addr_sig <= std_logic_vector(to_unsigned(addr, 16));
        data_sig <= value;
        en_sig   <= '1';
        we_sig   <= '1';

        wait until rising_edge(clk);
        wait for 2 ns;

        en_sig   <= '0';
        we_sig   <= '0';
        addr_sig <= (others => '0');
        data_sig <= (others => '0');
    end procedure;

   
    --------------------------------------------------
    -- run one operation with common checks
    --------------------------------------------------
    procedure run_operation (
        signal clk          : in  std_logic;
        signal start_sig    : out std_logic;
        signal op_sig       : out std_logic_vector(1 downto 0);
        signal id_sig       : out std_logic_vector(5 downto 0);
        signal prio_sig     : out std_logic_vector(1 downto 0);
        signal done_sig     : in  std_logic;
        signal count_sig    : in  std_logic_vector(7 downto 0);
        signal task_out_sig : in  std_logic_vector(5 downto 0);
        constant op_val     : in  std_logic_vector(1 downto 0);
        constant id_val     : in  std_logic_vector(5 downto 0);
        constant prio_val   : in  std_logic_vector(1 downto 0);
        constant count_val  : in  integer := -1;
        constant popped_id  : in  std_logic_vector(5 downto 0) := (others => '0')
    ) is
    begin
        op_number := op_number + 1;
        report "Starting operation " & integer'image(op_number) &
               ": OP="   & integer'image(to_integer(unsigned(op_val))) &
               ", ID="   & integer'image(to_integer(unsigned(id_val))) &
               ", PRIO=" & integer'image(to_integer(unsigned(prio_val)));

        assert done_sig = '0'
            report "TEST FAILED: run_operation called when DONE is not low"
            severity failure;

        op_sig    <= op_val;
        id_sig    <= id_val;
        prio_sig  <= prio_val;
        start_sig <= '1';

        wait until rising_edge(done_sig);

        if op_val = "01" then
            assert task_out_sig = popped_id
                report "TEST FAILED: pop returns an incorrect o_task_id" &
                       " expected=" & integer'image(to_integer(unsigned(popped_id))) &
                       " actual=" & integer'image(to_integer(unsigned(task_out_sig)))
                severity failure;
        end if;

        wait for 2 ns;

        if count_val >= 0 then
            assert count_val = to_integer(unsigned(count_sig))
                report "TEST FAILED: incorrect number of tasks in the list" &
                       " expected=" & integer'image(count_val) &
                       " actual=" & integer'image(to_integer(unsigned(count_sig)))
                severity failure;
        end if;

        start_sig <= '0';

        wait until falling_edge(done_sig);
        wait until falling_edge(clk);
    end procedure;

end package body;
