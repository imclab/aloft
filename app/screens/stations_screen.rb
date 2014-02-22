class StationsScreen < PM::TableScreen
  title "Weather Stations"

  def on_load
    rmq.stylesheet = StationsStylesheet
    view.rmq.apply_style :root_view

    @stations = []
    set_nav_bar_button(:left, title: "Close", action: :close) unless App::Persistence['station'].nil?
    refresh
  end

  def table_data
    [{
      title: "Select weather station near you:",
      cells: @stations
    }]
  end

  def refresh
    ap "refreshing" if BW.debug?
    BW::Location.get_once do |location|
      ap "got location." if BW.debug?
      find_stations(location)
    end
  end

  def find_stations(location)
    ap "Finding stations" if BW.debug?
    Stations.client.sorted_by_distance_from(location) do |s|

      @stations = s.map do |station|
        {
          title: station[:name],
          subtitle: subtitle(station),
          action: :select_station,
          height: 60,
          arguments: { station: station }
        }
      end
      update_table_data
    end
  end

  def subtitle(station)
    miles = station[:current_distance].miles.round
    state = station[:state_abbrev]
    "About #{miles} miles away. #{station[:city]}, #{state}"
  end

  def select_station(args = {})
    App::Persistence['station'] = args[:station][:code]
    close
  end

  def close
    dismissModalViewControllerAnimated(true)
  end

end
