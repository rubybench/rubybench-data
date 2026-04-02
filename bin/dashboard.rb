#!/usr/bin/env ruby
require 'yaml'

def format_float(float)
  ('%0.2f' % float).to_f
end

# 20250908 -> "2025-09-08"
def to_date(ruby)
  year = ruby / 10000
  month = ruby / 100 % 100
  day = ruby % 100
  "%04d-%02d-%02d" % [year, month, day]
end

def stringify_keys(obj)
  case obj
  when Hash
    obj.transform_keys(&:to_s).transform_values { |v| stringify_keys(v) }
  else
    obj
  end
end

benchmarks_yml = ARGV[0] || 'benchmarks.yml'

rubies = YAML.load_file('rubies.yml').keys
benchmarks = YAML.load_file(benchmarks_yml, symbolize_names: true)
benchmarks.select! { |benchmark, _| !benchmark.to_s.include?('ractor/') }
benchmark_results = benchmarks.map do |benchmark, _|
  path = "ruby-bench/#{benchmark}.yml"
  [benchmark, File.exist?(path) ? YAML.load_file(path) : {}]
end.to_h
rss_results = benchmarks.map do |benchmark, _|
  path = "ruby-bench-rss/#{benchmark}.yml"
  [benchmark, File.exist?(path) ? YAML.load_file(path) : {}]
end.to_h

ruby = rubies.select { |ruby| benchmark_results.first.last.key?(ruby) }.max
rss_ruby = rss_results.values.flat_map(&:keys).max
dashboard = {
  date: to_date(ruby),
  rss_date: rss_ruby ? to_date(rss_ruby) : nil,
  headline: {
    no_jit: [],
    yjit: [],
    zjit: [],
    benchmarks: [],
    rss: { no_jit: [], yjit: [], zjit: [], benchmarks: [] },
  },
  other: {
    no_jit: [],
    yjit: [],
    zjit: [],
    benchmarks: [],
    rss: { no_jit: [], yjit: [], zjit: [], benchmarks: [] },
  },
  micro: {
    no_jit: [],
    yjit: [],
    zjit: [],
    benchmarks: [],
    rss: { no_jit: [], yjit: [], zjit: [], benchmarks: [] },
  },
}

benchmarks.sort_by(&:first).each do |benchmark, metadata|
  results = benchmark_results.fetch(benchmark)
  category = metadata.fetch(:category, 'other').to_sym
  next unless dashboard.key?(category)

  no_jit, yjit, zjit = results[ruby]
  if no_jit
    dashboard[category][:no_jit] << format_float(no_jit / no_jit)
    dashboard[category][:yjit] << (yjit ? format_float(no_jit / yjit) : 0.0)
    dashboard[category][:zjit] << (zjit ? format_float(no_jit / zjit) : 0.0)
    dashboard[category][:benchmarks] << benchmark.to_s
  end

  rss = rss_results.fetch(benchmark)
  rss_no_jit, rss_yjit, rss_zjit = rss[rss_ruby]
  if rss_ruby && rss_no_jit
    dashboard[category][:rss][:no_jit] << format_float(rss_no_jit / rss_no_jit)
    dashboard[category][:rss][:yjit] << (rss_yjit ? format_float(rss_yjit / rss_no_jit) : 0.0)
    dashboard[category][:rss][:zjit] << (rss_zjit ? format_float(rss_zjit / rss_no_jit) : 0.0)
    dashboard[category][:rss][:benchmarks] << benchmark.to_s
  end
end

File.write('dashboard.yml', stringify_keys(dashboard).to_yaml)
