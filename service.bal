import ballerina/random;
import ballerina/http;

map<status> orderStatus = {};
map<int> menu = {};

enum status {
    pending,
    in\ progress,
    completed
}

type Order record {
    string username;
    OrderItem[] order_items;
};

type UpdateOrder record {
    OrderItem[] order_items;
};

type OrderItem record {
    string item;
    int quantity;
};

service / on new http:Listener(9090) {

    function init() {
        menu["Butter Cake"] = 15;
        menu["Chocolate Cake"] = 20;
        menu["Tres Leches"] = 25;
    }

    resource function get menu() returns json {
        return menu.toJson();
    }

    resource function post 'order(@http:Payload json payload) returns http:Created|http:BadRequest|error {
        if payload.username == "" {
            http:BadRequest badRequest = {body: "Empty username"};
            return badRequest;
        }

        do {
            Order orderDetails = check payload.cloneWithType();
            int|boolean totalAmount = findTotal(orderDetails.order_items);
            if totalAmount is boolean {
                http:BadRequest badRequest = {body: "Invalid payload"};
                return badRequest;
            }

            int orderNo = check random:createIntInRange(1, 1000000);
            orderStatus[orderNo.toString()] = pending;
            json outputJson = {"order_id": orderNo.toString(), "total": totalAmount};
            http:Created createdResponse = {body: outputJson};
            return createdResponse;
        } on fail {
            http:BadRequest badRequest = {body: "Invalid payload"};
            return badRequest;
        }
    }

    resource function get 'order/[string orderId]() returns http:NotFound|http:Ok {
        status? orderInfo = orderStatus[orderId];
        if orderInfo is () {
            http:NotFound notFound = {body: "Order not found"};
            return notFound;
        }

        json responseMsg = {"order_id": orderId, "status": orderInfo};
        http:Ok sucessResponse = {body: responseMsg};
        return sucessResponse;
    }

    resource function put 'order/[string orderId](@http:Payload json payload) 
        returns http:BadRequest|http:Forbidden|http:NotFound|http:Ok {

        status? orderInfo = orderStatus[orderId];
        if orderInfo is () {
            http:NotFound notFound = {body: "Order not found"};
            return notFound;
        }

        if orderInfo != pending {
            http:Forbidden forbiddenMsg = {body: "Not allowed since status is not pending"};
            return forbiddenMsg;
        }

        do {
            UpdateOrder updateOrder = check payload.cloneWithType();
            int|boolean totalAmount = findTotal(updateOrder.order_items);
            if totalAmount is boolean {
                http:BadRequest badRequest = {body: "Invalid payload"};
                return badRequest;
            }

            json outputJson = {"order_id": orderId, "total": totalAmount};
            http:Ok ok = {body: outputJson};
            return ok;
        } on fail {
            http:BadRequest badRequest = {body: "Invalid payload"};
            return badRequest;
        }
    }

    resource function delete 'order/[string orderId]() returns http:NotFound|http:Ok|http:Forbidden {
        status? orderInfo = orderStatus[orderId];
        if orderInfo is () {
            http:NotFound notFound = {body: "Order not found"};
            return notFound;
        }

        if orderInfo != pending {
            http:Forbidden forbiddenMsg = {body: "Not allowed since status is not pending"};
            return forbiddenMsg;
        } else {
            _ = orderStatus.remove(orderId);
            http:Ok ok = {body: "Order deleted"};
            return ok;
        }
    }
}

function findTotal(OrderItem[] orderItems) returns int|boolean {
    if orderItems.length() == 0 {
        return false;
    }

    int totalAmount = 0;
    string[] menuItems = menu.keys();
    foreach var {item, quantity} in orderItems {
        int? itemValue = menu[item];
        int? menuItemIndex = menuItems.indexOf(item);
        if itemValue is () || quantity <= 0 ||
        menuItemIndex is () {
            return false;
        } else {
            totalAmount += (itemValue * quantity);
            _ = menuItems.remove(menuItemIndex);
        }
    }

    return totalAmount;
}

