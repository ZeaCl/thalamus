defmodule TestRollback2 do
  def test do
    result = Thalamus.Repo.transaction(fn ->
      # Insert a valid org
      Thalamus.Repo.insert!(%Thalamus.Infrastructure.Persistence.Schemas.OrganizationSchema{
        name: "Test Rollback Org 2",
        plan_type: :free,
        max_users: 10,
        max_api_calls_per_month: 1000
      })
      Thalamus.Repo.rollback(:my_custom_error)
    end)
    
    org = Thalamus.Repo.one(Ecto.Query.where(Thalamus.Infrastructure.Persistence.Schemas.OrganizationSchema, name: "Test Rollback Org 2"))
    
    IO.puts("Transaction result: #{inspect(result)}")
    IO.puts("Org exists after rollback? #{inspect(org != nil)}")
  end
end

TestRollback2.test()
