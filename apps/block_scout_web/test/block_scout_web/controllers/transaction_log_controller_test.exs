defmodule BlockScoutWeb.TransactionLogControllerTest do
  use BlockScoutWeb.ConnCase

  import BlockScoutWeb.Router.Helpers, only: [transaction_log_path: 3]

  alias Explorer.ExchangeRates.Token

  describe "GET index/2" do
    test "with invalid transaction hash", %{conn: conn} do
      conn = get(conn, transaction_log_path(conn, :index, "invalid_transaction_string"))

      assert html_response(conn, 422)
    end

    test "with valid transaction hash without transaction", %{conn: conn} do
      conn =
        get(
          conn,
          transaction_log_path(conn, :index, "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6")
        )

      assert html_response(conn, 404)
    end

    test "returns logs for the transaction", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      address = insert(:address)
      insert(:log, address: address, transaction: transaction)

      conn = get(conn, transaction_log_path(conn, :index, transaction))

      first_log = List.first(conn.assigns.logs)

      assert first_log.transaction_hash == transaction.hash
    end

    test "returns logs for the transaction with nil to_address", %{conn: conn} do
      transaction =
        :transaction
        |> insert(to_address: nil)
        |> with_block()

      address = insert(:address)
      insert(:log, address: address, transaction: transaction)

      conn = get(conn, transaction_log_path(conn, :index, transaction))

      first_log = List.first(conn.assigns.logs)

      assert first_log.transaction_hash == transaction.hash
    end

    test "assigns no logs when there are none", %{conn: conn} do
      transaction = insert(:transaction)
      path = transaction_log_path(conn, :index, transaction)

      conn = get(conn, path)

      assert Enum.count(conn.assigns.logs) == 0
    end

    test "returns next page of results based on last seen transaction log", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      log = insert(:log, transaction: transaction, index: 1)

      second_page_indexes =
        2..51
        |> Enum.map(fn index -> insert(:log, transaction: transaction, index: index) end)
        |> Enum.map(& &1.index)

      conn =
        get(conn, transaction_log_path(conn, :index, transaction), %{
          "index" => Integer.to_string(log.index)
        })

      actual_indexes = Enum.map(conn.assigns.logs, & &1.index)

      assert second_page_indexes == actual_indexes
    end

    test "next_page_params exist if not on last page", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      1..60
      |> Enum.map(fn index -> insert(:log, transaction: transaction, index: index) end)

      conn = get(conn, transaction_log_path(conn, :index, transaction))

      assert %{"index" => 50} = conn.assigns.next_page_params
    end

    test "next_page_params are empty if on last page", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      conn = get(conn, transaction_log_path(conn, :index, transaction))

      refute conn.assigns.next_page_params
    end
  end

  test "includes USD exchange rate value for address in assigns", %{conn: conn} do
    transaction = insert(:transaction)

    conn = get(conn, transaction_log_path(BlockScoutWeb.Endpoint, :index, transaction.hash))

    assert %Token{} = conn.assigns.exchange_rate
  end

  test "loads for transactions that created a contract", %{conn: conn} do
    contract_address = insert(:contract_address)

    transaction =
      :transaction
      |> insert(to_address: nil)
      |> with_contract_creation(contract_address)

    conn = get(conn, transaction_log_path(conn, :index, transaction))
    assert html_response(conn, 200)
  end
end