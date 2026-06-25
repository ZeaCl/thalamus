defmodule TestRollback do
  def test do
    result = Thalamus.Repo.transaction(fn ->
      Thalamus.Repo.insert!(%Thalamus.Infrastructure.Persistence.Schemas.OrganizationSchema{
        name: "Test Rollback Org",
        plan_type: :free
      })
      Thalamus.Repo.rollback(:my_custom_error)
    end)
    
    org = Thalamus.Repo.one(Ecto.Query.where(Thalamus.Infrastructure.Persistence.Schemas.OrganizationSchema, name: "Test Rollback Org"))
    
    IO.puts("Transaction result: #{inspect(result)}")
    IO.puts("Org exists after rollback? #{inspect(org != nil)}")
  end
end

TestRollback.test()
