# GridView
> UICollectionView wrapper for SwiftUI.

Basic implementation:
```swift
GridView { snapshot in
    snapshot.addSection(models, fill: { 
        ModelView(model: $0) 
    })
}                
```

By default it uses full width layout for a single cell, you can customize it:
```swift
GridView { snapshot in
    snapshot.addSection(models, fill: { 
        ModelView(model: $0) 
    }, layout: { 
        .grid($0) 
    })
} 
```

A custom view can be added to the snapshot:
```swift
snapshot.add(SomeView())
snapshot.add(SomeView(), staticHeight: 100)
```

Empty state support with `EmptyState` struct. By default the empty state is shown if there are no items in current snapshot. You can change it by supplying your own `isPresented` closure:
```swift
let emptyState = EmptyState {
    EmptyStateView(title: "No Data")
} isPresented: {
    return true
}

GridView(emptyState: emptyState) { snapshot in
    snapshot.addSection(models, fill: { 
        ModelView(model: $0) 
    })
} 
```
                
Refresh support. If refresh operation closure is supplied a UIRefreshControl will be added:
```swift
GridView(refresh: { await refreshOperation() }) { snapshot in
    snapshot.addSection(models, fill: { 
        ModelView(model: $0) 
    })
} 
```

## Meta

Ilya Kuznetsov – i.v.kuznecov@gmail.com

Distributed under the MIT license. See ``LICENSE`` for more information.

[https://github.com/ivkuznetsov](https://github.com/ivkuznetsov)
