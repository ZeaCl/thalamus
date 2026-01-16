# Script to test Redis connectivity and cache performance
# Usage: mix run scripts/test_redis.exs

defmodule RedisTest do
  @moduledoc """
  Tests Redis cache functionality and performance.
  """

  alias Thalamus.Infrastructure.Adapters.RedisCacheAdapter

  def run do
    IO.puts("\n🔍 Testing Redis Connection...")
    IO.puts("=" |> String.duplicate(60))

    # Test 1: Ping
    case RedisCacheAdapter.ping() do
      {:ok, "PONG"} ->
        IO.puts("✅ Redis is connected and responding")

      {:error, reason} ->
        IO.puts("❌ Redis connection failed: #{inspect(reason)}")
        IO.puts("\n💡 Make sure Redis is running:")
        IO.puts("   docker compose up -d redis")
        IO.puts("   OR")
        IO.puts("   docker run -d --name thalamus_redis -p 6379:6379 redis:7-alpine")
        System.halt(1)
    end

    # Test 2: Set/Get
    IO.puts("\n📝 Testing SET/GET operations...")

    test_key = "test:#{System.system_time(:millisecond)}"
    test_value = %{
      message: "Hello from Redis!",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    case RedisCacheAdapter.set(test_key, test_value, 60) do
      :ok ->
        IO.puts("✅ SET operation successful")

      {:error, reason} ->
        IO.puts("❌ SET failed: #{inspect(reason)}")
        System.halt(1)
    end

    case RedisCacheAdapter.get(test_key) do
      {:ok, ^test_value} ->
        IO.puts("✅ GET operation successful - value matches")

      {:ok, value} ->
        IO.puts("⚠️  GET returned different value: #{inspect(value)}")

      {:error, reason} ->
        IO.puts("❌ GET failed: #{inspect(reason)}")
        System.halt(1)
    end

    # Test 3: Exists
    IO.puts("\n🔎 Testing EXISTS operation...")

    case RedisCacheAdapter.exists?(test_key) do
      {:ok, true} ->
        IO.puts("✅ EXISTS returned true (key found)")

      {:ok, false} ->
        IO.puts("❌ EXISTS returned false (key not found)")

      {:error, reason} ->
        IO.puts("❌ EXISTS failed: #{inspect(reason)}")
    end

    # Test 4: Delete
    IO.puts("\n🗑️  Testing DELETE operation...")

    case RedisCacheAdapter.delete(test_key) do
      :ok ->
        IO.puts("✅ DELETE operation successful")

      {:error, reason} ->
        IO.puts("❌ DELETE failed: #{inspect(reason)}")
    end

    # Verify deletion
    case RedisCacheAdapter.get(test_key) do
      {:error, :not_found} ->
        IO.puts("✅ Key deleted successfully (GET returned :not_found)")

      {:ok, _value} ->
        IO.puts("❌ Key still exists after deletion")
    end

    # Test 5: Performance benchmark
    IO.puts("\n⚡ Running performance benchmark...")
    benchmark_cache_performance()

    IO.puts("\n" <> ("=" |> String.duplicate(60)))
    IO.puts("✨ All Redis tests passed!")
    IO.puts("=" |> String.duplicate(60))
  end

  defp benchmark_cache_performance do
    iterations = 1000

    # Warm up
    Enum.each(1..10, fn i ->
      RedisCacheAdapter.set("warmup:#{i}", %{data: i}, 10)
      RedisCacheAdapter.get("warmup:#{i}")
    end)

    # Benchmark SET
    {set_time_us, _} =
      :timer.tc(fn ->
        Enum.each(1..iterations, fn i ->
          RedisCacheAdapter.set("bench:#{i}", %{iteration: i}, 60)
        end)
      end)

    set_avg_ms = set_time_us / iterations / 1000

    # Benchmark GET
    {get_time_us, _} =
      :timer.tc(fn ->
        Enum.each(1..iterations, fn i ->
          RedisCacheAdapter.get("bench:#{i}")
        end)
      end)

    get_avg_ms = get_time_us / iterations / 1000

    IO.puts("  SET operations: #{Float.round(set_avg_ms, 3)}ms average (#{iterations} ops)")
    IO.puts("  GET operations: #{Float.round(get_avg_ms, 3)}ms average (#{iterations} ops)")

    if get_avg_ms < 3.0 do
      IO.puts("  🎯 Target achieved: < 3ms per GET operation")
    else
      IO.puts("  ⚠️  Target missed: #{Float.round(get_avg_ms, 3)}ms > 3ms target")
    end

    # Cleanup
    Enum.each(1..iterations, fn i ->
      RedisCacheAdapter.delete("bench:#{i}")
    end)
  end
end

# Run tests
RedisTest.run()
