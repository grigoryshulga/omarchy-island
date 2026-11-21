// Loaded only inside the isolated test shell. Query the platform interface used
// by accessibility bridges, including the real action and range setters.
#include <QAccessible>
#include <QQmlExtensionPlugin>
#include <QQuickItem>
#include <QQuickWindow>

class AccessibilityProbe : public QObject
{
    Q_OBJECT

    // A composite slider may provide its value interface on its focus child.
    static QAccessibleInterface *find(QAccessibleInterface *node, QQuickItem *scope)
    {
        if (!node)
            return nullptr;
        auto *item = qobject_cast<QQuickItem *>(node->object());
        if (scope == item || (item && scope->isAncestorOf(item)))
            return node;
        for (int index = 0; index < node->childCount(); ++index)
            if (auto *match = find(node->child(index), scope))
                return match;
        return nullptr;
    }

    static QAccessibleInterface *control(QQuickItem *scope)
    {
        return scope && scope->window()
            ? find(QAccessible::queryAccessibleInterface(scope->window()), scope) : nullptr;
    }

public:
    Q_INVOKABLE QVariantMap inspect(QQuickItem *scope) const
    {
        auto *iface = control(scope);
        if (!iface)
            return {};
        QVariantMap state {
            {"name", iface->text(QAccessible::Name)},
            {"description", iface->text(QAccessible::Description)},
            {"role", int(iface->role())},
            {"selected", bool(iface->state().selected)},
            {"disabled", bool(iface->state().disabled)},
        };
        if (auto *range = iface->valueInterface()) {
            state.insert("value", range->currentValue());
            state.insert("minimum", range->minimumValue());
            state.insert("maximum", range->maximumValue());
            state.insert("step", range->minimumStepSize());
        }
        return state;
    }

    Q_INVOKABLE bool setValue(QQuickItem *scope, double value) const
    {
        auto *iface = control(scope);
        auto *range = iface ? iface->valueInterface() : nullptr;
        if (!range)
            return false;
        range->setCurrentValue(value);
        return true;
    }

    Q_INVOKABLE bool act(QQuickItem *scope, const QString &action) const
    {
        auto *iface = control(scope);
        auto *actions = iface ? iface->actionInterface() : nullptr;
        if (!actions || !actions->actionNames().contains(action))
            return false;
        actions->doAction(action);
        return true;
    }
};

class AccessibilityTestPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)

public:
    void registerTypes(const char *uri) override
    {
        QAccessible::setActive(true);
        qmlRegisterType<AccessibilityProbe>(uri, 1, 0, "AccessibilityProbe");
    }
};

#include "AccessibilityProbe.moc"
