defmodule NeoscanSync.FastSync do
  @moduledoc false

  @moduledoc """

    External process to fetch blockchain from RCP node sync, and print json

  """

  alias NeoscanSync.Blockchain
  alias Neoscan.Pool
  alias NeoscanSync.BlockSync

  @me __MODULE__

  #Starts the application
  def start_link() do
    Agent.start_link(fn -> start() end , name: @me)
  end


  #Start process, create file and get current height from the chain
  def start(n \\ 250) do
    alive = Process.whereis(Neoscan.Supervisor)
    |> Process.alive?
    case alive do
      true ->
        fetch_chain(n)
      false ->
        IO.puts("Main process was killed")
        Process.exit(self(), :shutdown)
    end

  end

  def fetch_chain(n) do
    count = Pool.get_highest_block_in_pool()
    # IO.puts(count)
    # IO.puts(get_current_height(Enum.random(0..9)))
    get_current_height(Enum.random(0..9))
    |> evaluate(n, count+1)
  end

  #evaluate number of process, current block count, and start async functions
  defp evaluate(result, n, count) do
    case result do
      {:ok, height} when (height-2) > count  ->
        cond do
          height - 100 - count >= n ->
            Enum.to_list(count..(count+n-1))
            |> Enum.map(&Task.async(fn -> cross_check(&1) end))
            |> Enum.map(&Task.await(&1, 20000))
            |> Enum.map(fn x -> add_block(x) end)
            start(n)
           height - 100 - count < n ->
            Enum.to_list(count..(height-100))
            |> Enum.map(&Task.async(fn -> cross_check(&1) end))
            |> Enum.map(&Task.await(&1, 20000))
            |> Enum.map(fn x -> add_block(x) end)
            BlockSync.start()
        end
      {:ok, height} when (height-100) == count  ->
        BlockSync.start()
    end
  end

  #write block to the file
  def add_block(%{"index" => num} = block) do
    %{"height" => num, "block" => block}
    |> Pool.create_data()
    IO.puts("Block #{num} saved in pool")
  end

  #cross check block hash between different seeds
  def cross_check(height) do
    random1 = Enum.random(0..9)
    random2= cond do
      random1 == 9 ->
         1
      true ->
        random1 + 1
    end
    blockA = get_block_by_height(random1, height)
    blockB = get_block_by_height(random2, height)
    %{"hash" => hashA} = blockA
    %{"hash" => hashB} = blockB
    cond do
      hashA == hashB ->
        blockA
      true ->
        cross_check(height)
    end
  end


  #handles error when fetching block from chain
  def get_block_by_height(random, height) do
    case Blockchain.get_block_by_height(random, height) do
      { :ok , block } ->
        block
      { :error, _reason} ->
        get_block_by_height(random, height)
    end
  end

  #handles error when fetching height from chain
  def get_current_height(random) do
    case Blockchain.get_current_height(random) do
      { :ok , height } ->
        { :ok , height }
      { :error, _reason} ->
        get_current_height(random)
    end
  end

end
