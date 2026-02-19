defschema Student do
  field :name, :string
  field :age, :integer
  field :graduation_year, :integer, optional: true
end

defschema Class do
  field :name, :string
end
