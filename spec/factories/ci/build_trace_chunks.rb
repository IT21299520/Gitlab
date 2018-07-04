FactoryBot.define do
  factory :ci_build_trace_chunk, class: Ci::BuildTraceChunk do
    build factory: :ci_build
    chunk_index 0
    data_store :redis

    trait :redis_with_data do
      data_store :redis

      transient do
        initial_data 'test data'
      end

      after(:create) do |build_trace_chunk, evaluator|
        ::Ci::BuildTraceChunk::Redis.new.set_data(build_trace_chunk, evaluator.initial_data)
      end
    end

    trait :redis_without_data do
      data_store :redis
    end

    trait :database_with_data do
      data_store :database

      transient do
        initial_data 'test data'
      end

      after(:build) do |build_trace_chunk, evaluator|
        ::Ci::BuildTraceChunk::Database.new.set_data(build_trace_chunk, evaluator.initial_data)
      end
    end

    trait :database_without_data do
      data_store :database
    end

    trait :fog_with_data do
      data_store :fog

      transient do
        initial_data 'test data'
      end

      after(:create) do |build_trace_chunk, evaluator|
        ::Ci::BuildTraceChunk::Fog.new.set_data(build_trace_chunk, evaluator.initial_data)
      end
    end

    trait :fog_without_data do
      data_store :fog
    end
  end
end
