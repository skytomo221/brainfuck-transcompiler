# frozen_string_literal: true

require 'brainfuck_transcompiler'

bt = BrainfuckTranscompiler::Translator.new
bt.read('./sample/mandelbrot.bf').translate
puts '🐌 最適化前'
puts bt.to_c
File.write('a.c', bt.to_c)
bt.compression
puts '🚀 最適化後'
puts bt.to_c
File.write('b.c', bt.to_c)
