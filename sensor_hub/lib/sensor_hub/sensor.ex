defmodule SensorHub.Sensor do
  defstruct [:name, :fields, :read, :convert]

  def new(name) do
    %__MODULE__{
      read: read_fn(name),
      convert: convert_fn(name),
      fields: fields(name),
      name: name
    }
  end

  def fields(SGP40), do: [:voc_index]
  def fields(BMP280), do: [:altitude_m, :pressure_pa, :temperature_c, :humidity_rh, :dew_point_c, :gas_resistance_ohms]
  def fields(VEML6030), do: [:light_lumens]

  def read_fn(SGP40), do: fn -> SGP40.measure(SGP40) end
  def read_fn(BMP280), do: fn -> BMP280.measure(BMP280) end
  def read_fn(VEML6030), do: fn -> VEML6030.get_measurement() end

  def convert_fn(SGP40) do
    fn reading ->
      case reading do
        {:ok, measurement} ->
          Map.take(measurement, [:voc_index])
	_ -> %{}
      end
    end
  end

  def convert_fn(BMP280) do
    apply_transformation = fn {key, value} ->
        new_value =
          case key do
            :altitude_m -> abs(value) - 100
            :pressure_pa -> value / 100
            #:temperature_c -> value
            #:humidity_rh -> value
            #:dew_point_c -> value
            #:gas_resistance_ohms -> value
            _ -> value
          end
        {key, new_value}
      end

    fn reading ->
      case reading do
        {:ok, measurement} ->
          updates = measurement
          |> Map.from_struct()
          |> Enum.map(apply_transformation)
          |> Enum.into(%{})

          output_struct = struct!(measurement, updates)
          |> Map.take([:altitude_m, :pressure_pa, :temperature_c, :humidity_rh, :dew_point_c, :gas_resistance_ohms])
          output_struct
        _ ->
          %{}
      end
    end
  end

  def convert_fn(VEML6030) do
    fn data -> %{light_lumens: data} end
  end

  def measure(sensor) do
    sensor.read.()
    |> sensor.convert.()
  end
end
