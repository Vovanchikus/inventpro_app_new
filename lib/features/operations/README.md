# Operations Feature Module

This feature follows MVVM and clean layering to isolate API integration from presentation.

## Structure

- data/models: raw DTO objects that mirror the server payloads
- data/mappers: converters between DTOs and domain entities
- data/repositories: networking code that talks to the API
- domain/entities: pure Dart models used by business logic and viewmodels
- domain/usecases: reusable logic such as grouping, filtering, and aggregations
- presentation/viewmodels: state holders that orchestrate use cases for the UI
- presentation/views: widgets/screens that render the operations history
- presentation/widgets: smaller UI components (cards, list items, filters)

Each layer depends only on the layer directly beneath it, keeping responsibilities well separated.
