# frozen_string_literal: true

require_relative 'brainfuck_transcompiler/version'

module BrainfuckTranscompiler
  # Sentence
  class Sentence
    attr_reader :operator, :operand

    def initialize(operator)
      @operator = operator
    end
  end

  # Signed
  class Signed < Sentence
    attr_reader :positive

    def initialize(operator, operand = 1, positive: true)
      super(operator)
      @operand = operand
      @positive = positive
    end

    def signed_operand
      positive ? operand : -operand
    end

    def normalization
      NotImplementedError
    end
  end

  # Operator '>' or '<'
  class PointerIncrementable < Signed
    def normalization
      if signed_operand >= 0
        Increment.new(signed_operand)
      else
        Decrement.new(-signed_operand)
      end
    end
  end

  # Operator '>'
  class Increment < PointerIncrementable
    def initialize(operand = 1)
      super(:>, operand)
    end
  end

  # Operator '<'
  class Decrement < PointerIncrementable
    def initialize(operand = 1)
      super(:<, operand, positive: false)
    end
  end

  # Operator '+' or '-'
  class Incrementable < Signed
    def normalization
      if signed_operand >= 0
        Plus.new(signed_operand)
      else
        Minus.new(-signed_operand)
      end
    end
  end

  # Operator '+'
  class Plus < Incrementable
    def initialize(operand = 1)
      super(:+, operand)
    end
  end

  # Operator '-'
  class Minus < Incrementable
    def initialize(operand = 1)
      super(:-, operand, positive: false)
    end
  end

  # Operator '.'
  class Output < Sentence
    def initialize
      super :'.'
    end
  end

  # Operator ','
  class Input < Sentence
    def initialize
      super :','
    end
  end

  # Operator '['
  class LoopStart < Sentence
    def initialize
      super :'['
    end
  end

  # Operator ']'
  class LoopEnd < Sentence
    def initialize
      super :']'
    end
  end

  # Assignment
  class Assignment < Sentence
    attr_reader :destination

    def initialize(operand = 0, destination = nil)
      super :assignment
      @operand = operand
      @destination = destination
    end
  end

  # Brainfuck transcompiler
  class Translator
    attr_reader :source, :code

    def read(path)
      @source = File.read(path)
      self
    end

    def translate
      @code = @source.chars.map do |c|
        tokenizer c
      end
      self
    end

    def pointer_increment_compression
      old_code = @code
      new_code = []
      prev = nil
      old_code.push(nil).each do |now|
        if prev.class < PointerIncrementable && now.class < PointerIncrementable
          prev = Increment.new(prev.signed_operand + now.signed_operand).normalization
          next
        end
        new_code << prev unless prev.nil?
        prev = now
      end
      @code = new_code.compact
    end

    def increment_compression
      old_code = @code
      new_code = []
      prev = nil
      old_code.push(nil).each do |now|
        if prev.class < Incrementable && now.class < Incrementable
          prev = Plus.new(prev.signed_operand + now.signed_operand).normalization
          next
        end
        new_code << prev unless prev.nil?
        prev = now
      end
      @code = new_code.compact
    end

    def zero_idiom
      old_code = @code
      new_code = []
      prev = nil
      prev_prev = nil
      old_code.push(nil).push(nil).each do |now|
        if prev_prev.instance_of?(LoopStart) && prev.instance_of?(Minus) && now.instance_of?(LoopEnd)
          new_code << Assignment.new
          prev_prev = prev = nil
        else
          new_code << prev_prev unless prev_prev.nil?
          prev_prev = prev
          prev = now
        end
      end
      @code = new_code.compact
    end

    def compression
      pointer_increment_compression
      increment_compression
      zero_idiom
      self
    end

    def to_c
      indent = 1
      head = <<~'C'
        #include <stdio.h>
        int main(void)
        {
          char mem[30000] = {0};
          char* ptr = mem;
      C
      body = ''
      @code.compact.each do |now|
        body += "#{' ' * 4 * indent}#{sentence_to_c(now)}\n"
        case now
        when LoopStart
          indent += 1
        when LoopEnd
          indent -= 1
        end
      end
      tail = '}'
      head + body + tail
    end

    private

    # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/AbcSize, Metrics/PerceivedComplexity
    def tokenizer(token)
      case token
      when '>'
        Increment.new
      when '<'
        Decrement.new
      when '+'
        Plus.new
      when '-'
        Minus.new
      when '.'
        Output.new
      when ','
        Input.new
      when '['
        LoopStart.new
      when ']'
        LoopEnd.new
      end
    end

    def sentence_to_c(sentence)
      case sentence
      when Increment
        if sentence.operand == 1
          'ptr++;'
        else
          "ptr += #{sentence.operand};"
        end
      when Decrement
        if sentence.operand == 1
          'ptr--;'
        else
          "ptr -= #{sentence.operand};"
        end
      when Plus
        if sentence.operand == 1
          '(*ptr)++;'
        else
          "(*ptr) += #{sentence.operand};"
        end
      when Minus
        if sentence.operand == 1
          '(*ptr)--;'
        else
          "(*ptr) -= #{sentence.operand};"
        end
      when Output
        'putchar(*ptr);'
      when Input
        '*ptr = getchar();'
      when LoopStart
        'while(*ptr) {'
      when LoopEnd
        '}'
      when Assignment
        if sentence.destination.nil?
          "*ptr = #{sentence.operand};"
        else
          "ptr[#{sentence.destination}] = #{sentence.operand};"
        end
      else
        NotImplementedError
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/AbcSize, Metrics/PerceivedComplexity
  end
end
