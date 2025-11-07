//
//  PerformanceOptimizations.swift
//  Notis
//
//  Created by Mike on 11/3/25.
//

import SwiftUI
import CoreData
import Combine

#if os(iOS)
import UIKit
#endif

#if os(macOS)
import AppKit
#endif

// MARK: - Lazy Loading Container
struct LazyContentView<Content: View>: View {
    let threshold: CGFloat
    let content: () -> Content
    
    @State private var isVisible = false
    @State private var hasAppeared = false
    
    init(threshold: CGFloat = 100, @ViewBuilder content: @escaping () -> Content) {
        self.threshold = threshold
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geometry in
            if isVisible || hasAppeared {
                content()
                    .onAppear {
                        hasAppeared = true
                    }
            } else {
                Color.clear
                    .onAppear {
                        // Check if view is within threshold of viewport
                        if geometry.frame(in: .global).minY < UIScreen.main.bounds.height + threshold {
                            withAnimation(UlyssesDesign.Animations.gentle) {
                                isVisible = true
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - Debounced TextField
struct DebouncedTextField: View {
    let title: String
    @Binding var text: String
    let delay: TimeInterval
    let onSearchCommitted: (String) -> Void
    
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        TextField(title, text: $searchText)
            .onChange(of: searchText) { oldValue, newValue in
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
                    
                    if !Task.isCancelled {
                        await MainActor.run {
                            text = newValue
                            onSearchCommitted(newValue)
                        }
                    }
                }
            }
            .onAppear {
                searchText = text
            }
            .onDisappear {
                searchTask?.cancel()
            }
    }
}

// MARK: - Optimized Core Data Fetching
class OptimizedFetchManager: ObservableObject {
    private let context: NSManagedObjectContext
    
    @Published var sheets: [Sheet] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func fetchSheets(
        for group: Group? = nil,
        searchText: String = "",
        limit: Int = 50,
        offset: Int = 0
    ) {
        isLoading = true
        error = nil
        
        Task {
            do {
                let request: NSFetchRequest<Sheet> = Sheet.fetchRequest()
                request.fetchLimit = limit
                request.fetchOffset = offset
                request.returnsObjectsAsFaults = false
                
                // Build predicate
                var predicates: [NSPredicate] = [
                    NSPredicate(format: "isInTrash == NO")
                ]
                
                if let group = group {
                    predicates.append(NSPredicate(format: "group == %@", group))
                }
                
                if !searchText.isEmpty {
                    predicates.append(NSPredicate(
                        format: "title CONTAINS[cd] %@ OR content CONTAINS[cd] %@",
                        searchText, searchText
                    ))
                }
                
                request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
                request.sortDescriptors = [
                    NSSortDescriptor(keyPath: \Sheet.modifiedAt, ascending: false)
                ]
                
                let fetchedSheets = try context.fetch(request)
                
                await MainActor.run {
                    if offset == 0 {
                        self.sheets = fetchedSheets
                    } else {
                        self.sheets.append(contentsOf: fetchedSheets)
                    }
                    self.isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Memory-Efficient Image Loading
struct OptimizedAsyncImage: View {
    let url: URL?
    let placeholder: Image
    
    @State private var image: Image?
    @State private var isLoading = false
    
    var body: some View {
        SwiftUI.Group {
            if let image = image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                placeholder
                    .opacity(0.3)
                    .overlay {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url, image == nil else { return }
        
        isLoading = true
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                
                #if os(iOS)
                if let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        self.image = Image(uiImage: uiImage)
                        self.isLoading = false
                    }
                }
                #elseif os(macOS)
                if let nsImage = NSImage(data: data) {
                    await MainActor.run {
                        self.image = Image(nsImage: nsImage)
                        self.isLoading = false
                    }
                }
                #endif
                
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Performance Monitoring
class PerformanceMonitor: ObservableObject {
    @Published var frameRate: Double = 60.0
    @Published var memoryUsage: Double = 0.0
    @Published var renderTime: TimeInterval = 0.0
    
    private var displayLink: CADisplayLink?
    private var frameCount = 0
    private var lastTimestamp: CFTimeInterval = 0
    
    func startMonitoring() {
        #if DEBUG
        #if os(iOS)
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkTick))
        displayLink?.add(to: .main, forMode: .default)
        #endif
        #endif
    }
    
    func stopMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func displayLinkTick(sender: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = sender.timestamp
            return
        }
        
        frameCount += 1
        
        let elapsed = sender.timestamp - lastTimestamp
        if elapsed >= 1.0 {
            DispatchQueue.main.async {
                self.frameRate = Double(self.frameCount) / elapsed
                self.memoryUsage = self.getCurrentMemoryUsage()
            }
            
            frameCount = 0
            lastTimestamp = sender.timestamp
        }
    }
    
    private func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // MB
        }
        return 0.0
    }
}

// MARK: - Smooth Scrolling List
struct SmoothScrollingList<Content: View>: View {
    let items: [AnyHashable]
    let content: (AnyHashable) -> Content
    
    @State private var scrollOffset: CGFloat = 0
    @State private var isScrolling = false
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element) { index, item in
                        LazyContentView {
                            content(item)
                        }
                        .id(index)
                    }
                }
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear {
                                scrollOffset = geometry.frame(in: .global).minY
                            }
                            .onChange(of: geometry.frame(in: .global).minY) { oldValue, newValue in
                                scrollOffset = newValue
                                
                                if !isScrolling {
                                    withAnimation(UlyssesDesign.Animations.quick) {
                                        isScrolling = true
                                    }
                                }
                                
                                // Reset scrolling state after delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation(UlyssesDesign.Animations.quick) {
                                        isScrolling = false
                                    }
                                }
                            }
                    }
                )
            }
            .scrollIndicators(.hidden)
            .overlay(alignment: .trailing) {
                if isScrolling {
                    Rectangle()
                        .fill(UlyssesDesign.Colors.accent.opacity(0.3))
                        .frame(width: 3)
                        .transition(.opacity.combined(with: .scale(scale: 0.5, anchor: .trailing)))
                }
            }
        }
    }
}

// MARK: - Cached View Modifier
struct CachedView<Content: View>: View {
    let content: () -> Content
    let cacheKey: String
    
    @State private var cachedView: AnyView?
    
    var body: some View {
        SwiftUI.Group {
            if let cachedView = cachedView {
                cachedView
            } else {
                content()
                    .onAppear {
                        cachedView = AnyView(content())
                    }
            }
        }
    }
}

extension View {
    func cached(key: String) -> some View {
        CachedView(content: { self }, cacheKey: key)
    }
}

import Combine

#Preview {
    VStack {
        DebouncedTextField(
            title: "Search",
            text: .constant(""),
            delay: 0.3
        ) { searchText in
            print("Search: \(searchText)")
        }
        
        LazyContentView {
            Text("This content loads lazily")
                .padding()
                .background(Color.blue.opacity(0.1))
        }
        .frame(height: 100)
    }
    .padding()
}