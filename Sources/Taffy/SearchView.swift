import AppKit
import SwiftUI

struct SearchView: View {
    @ObservedObject var model: SearchModel
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                TextField("Search tabs", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20))
                    .focused($fieldFocused)
                if model.isLoading {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()

            if model.results.isEmpty {
                emptyState
            } else {
                resultList
            }

            Divider()
            footer
        }
        .frame(width: 680, height: 460)
        .background(VisualEffectBackground())
        .onReceive(model.$focusToken) { _ in
            DispatchQueue.main.async { fieldFocused = true }
        }
    }

    private var resultList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(model.results.enumerated()), id: \.element.id) { index, item in
                        TabRow(item: item,
                               icon: model.icon(for: item.browser),
                               selected: index == model.selection)
                            .id(item.id)
                            .onTapGesture {
                                model.selection = index
                                model.activateSelected()
                            }
                    }
                }
                .padding(6)
            }
            .onChange(of: model.selection) { selection in
                guard model.results.indices.contains(selection) else { return }
                proxy.scrollTo(model.results[selection].id)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Spacer()
            if model.isLoading {
                Text("Loading tabs…")
            } else if !model.hasRunningBrowser {
                Text("No supported browser is running")
            } else {
                Text(model.query.isEmpty ? "No tabs" : "No matching tabs")
            }
            Spacer()
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text(model.query.isEmpty
                 ? "\(model.totalCount) tabs"
                 : "\(model.results.count) of \(model.totalCount) tabs")
            if let error = model.errors.first {
                Label(model.errors.count > 1 ? "\(error) (+\(model.errors.count - 1))" : error,
                      systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(model.errors.joined(separator: "\n"))
            }
            Spacer(minLength: 8)
            Text("↩ Open   ⌘⌫ Close tab   esc Dismiss")
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }
}

private struct TabRow: View {
    let item: TabItem
    let icon: NSImage
    let selected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayTitle)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(item.url)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            Text("\(item.browser.name) · W\(item.windowNumber)")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(selected ? Color.accentColor.opacity(0.28) : Color.clear)
        )
        .contentShape(Rectangle())
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
