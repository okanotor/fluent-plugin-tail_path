require_relative '../helper'

class TailPathInputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
    FileUtils.rm_rf(TMP_DIR)
    FileUtils.mkdir_p(TMP_DIR)
  end

  TMP_DIR = File.dirname(__FILE__) + "/../tmp/tail#{ENV['TEST_ENV_NUMBER']}"

  COMMON_CONFIG = %[
    path #{TMP_DIR}/tail.txt
    tag t1
    rotate_wait 2s
    pos_file #{TMP_DIR}/tail.pos
  ]
  SINGLE_LINE_CONFIG = %[
    format /(?<message>.*)/
  ]

  def create_driver(conf = SINGLE_LINE_CONFIG, use_common_conf = true)
    config = use_common_conf ? COMMON_CONFIG + conf : conf
    Fluent::Test::InputTestDriver.new(Fluent::NewTailPathInput).configure(config)
  end

  def test_path_key
    File.open("#{TMP_DIR}/tail.txt", "w") { |f| }

    d = create_driver(%[
       path #{TMP_DIR}/tail.txt
       tag t1
       format /(?<message>.*)/
       path_key foobar
    ], false)

    d.run do
      sleep 1

      File.open("#{TMP_DIR}/tail.txt", "a") {|f|
        f.puts "test1"
        f.puts "test2"
      }
      sleep 1
    end

    emits = d.emits
    assert_equal(true, emits.length > 0)
    assert_equal({"message"=>"test1", "foobar"=>"#{TMP_DIR}/tail.txt"}, emits[0][2])
    assert_equal({"message"=>"test2", "foobar"=>"#{TMP_DIR}/tail.txt"}, emits[1][2])
  end

  def test_path_key_multiline
    File.open("#{TMP_DIR}/tail2.txt", "w") { |f| }

    d = create_driver(%{
       path #{TMP_DIR}/tail2.txt
       tag t2
       format multiline
       format_firstline /\\[/
       format1 /\\[(?<message>.*)\\]/
       path_key foobar
    }, false)

    d.run do
      sleep 1

      File.open("#{TMP_DIR}/tail2.txt", "a") {|f|
        f.puts "[test1-1,"
        f.puts "test1-2,"
        f.puts "test1-3]"
        f.puts "[test2-1,"
        f.puts "test2-2,"
        f.puts "test2-3]"
      }
      sleep 1
    end

    emits = d.emits
    assert_equal(true, emits.length > 0)
    assert_equal({"message" => "test1-1,\ntest1-2,\ntest1-3", "foobar" => "#{TMP_DIR}/tail2.txt"}, emits[0][2])
    assert_equal({"message" => "test2-1,\ntest2-2,\ntest2-3", "foobar" => "#{TMP_DIR}/tail2.txt"}, emits[1][2])
  end
end
