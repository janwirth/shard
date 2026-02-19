defschema Student do
  field :name, :string
  field :age, :integer
  field :graduation_year, :integer, optional: true
  field :classes, [Class]
end

defschema Class do
  field :name, :string
  field :students, [Student, backlink: :classes]
end
