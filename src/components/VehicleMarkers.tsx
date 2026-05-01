import React, { useMemo } from 'react';
import { GeoJSONSource, Layer } from '@maplibre/maplibre-react-native';
import type { Feature, FeatureCollection, Point } from 'geojson';
import type { Vehicle, RoutesIndex } from '../api/types';
import { resolveLine } from '../api/lineLabel';
import { VEHICLE_COLORS } from '../constants/lodz';

type Props = {
  vehicles: Vehicle[];
  routes: RoutesIndex;
};

type VehicleProps = {
  number: string;
  type: 'tram' | 'bus' | 'unknown';
  routeId: string;
};

export function VehicleMarkers({ vehicles, routes }: Props): React.JSX.Element {
  const fc: FeatureCollection<Point, VehicleProps> = useMemo(() => {
    const features: Feature<Point, VehicleProps>[] = vehicles.map((v) => {
      const line = resolveLine(v.routeId, routes);
      return {
        type: 'Feature',
        geometry: { type: 'Point', coordinates: [v.lon, v.lat] },
        properties: { number: line.number, type: line.type, routeId: v.routeId },
      };
    });
    return { type: 'FeatureCollection', features };
  }, [vehicles, routes]);

  return (
    <GeoJSONSource id="vehicles" data={fc}>
      <Layer
        id="vehicle-circles"
        type="symbol"
        layout={{
          'icon-image': 'circle-15',
          'icon-size': 1.4,
          'icon-allow-overlap': true,
          'text-field': ['get', 'number'] as unknown as string,
          'text-size': 11,
          'text-allow-overlap': true,
          'text-font': ['Open Sans Bold'],
        }}
        paint={{
          'text-color': '#ffffff',
          'text-halo-color': [
            'match',
            ['get', 'type'],
            'tram', VEHICLE_COLORS.tram,
            'bus', VEHICLE_COLORS.bus,
            VEHICLE_COLORS.unknown,
          ] as unknown as string,
          'text-halo-width': 4,
        }}
      />
    </GeoJSONSource>
  );
}
