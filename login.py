import os
import sys
#sys.stdout = open(os.devnull, 'w')
#sys.stderr = open(os.devnull, 'w')
from selenium import webdriver
from selenium.webdriver.edge.service import Service as EdgeService
from webdriver_manager.microsoft import EdgeChromiumDriverManager
from selenium.webdriver.edge.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from PyQt5 import QtGui, QtWidgets, QtCore
from PyQt5.QtWidgets import QApplication, QMainWindow, QCheckBox, QTableWidgetItem
from PyQt5.QtCore import Qt, QThread, pyqtSignal, QMutex, QWaitCondition, QEventLoop
import requests
from datetime import datetime
from time import sleep
from math import ceil
from pathlib import Path
from lxml import html
import json
import base64
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import padding
from textwrap import fill
import threading



def resource_path(relative_path):
    """获取 PyInstaller 打包后的资源路径"""
    try:
        base_path = sys._MEIPASS
    except AttributeError:
        base_path = os.path.abspath(".")
    return os.path.join(base_path, relative_path)
for _k in ("HTTP_PROXY","HTTPS_PROXY","ALL_PROXY","http_proxy","https_proxy","all_proxy"):
    os.environ.pop(_k, None)
os.environ.setdefault("NO_PROXY", "*")
os.environ['WDM_CACHE_DIR'] = os.path.abspath('.')  # 当前文件夹
driver_path = EdgeChromiumDriverManager(url="https://msedgedriver.microsoft.com/",
            latest_release_url="https://msedgedriver.microsoft.com/LATEST_RELEASE").install()
service = EdgeService(driver_path)

session = requests.Session()
session.trust_env = False
session.proxies.clear()
USE_FIDDLER = False  # 想抓包 requests 时改为 True；不抓包改为 False
FIDDLER_PROXY = "http://127.0.0.1:8888"
FIDDLER_CA_PATH = resource_path("fiddler_root.pem")  # 从 Fiddler 导出的根证书（Base64），放到程序目录

def apply_fiddler_proxy(enable: bool):
    """按需切换 requests 到 Fiddler 代理，并配置证书校验。"""
    if enable:
        session.proxies.update({
            "http": FIDDLER_PROXY,
            "https": FIDDLER_PROXY,
        })
        if os.path.exists(FIDDLER_CA_PATH):
            session.verify = FIDDLER_CA_PATH  # 信任 Fiddler 根证书
            os.environ["REQUESTS_CA_BUNDLE"] = FIDDLER_CA_PATH
            os.environ["SSL_CERT_FILE"] = FIDDLER_CA_PATH
        else:
            session.verify = False  # 临时调试可用；生产不建议
    else:
        session.proxies.clear()
        session.verify = True  # 使用系统/默认 CA

# 启用/禁用 Fiddler 抓包（此时已下载好驱动）
apply_fiddler_proxy(USE_FIDDLER)
account=""
pwd=""
token=""
cookies=[]
number=0
xklcdm=""
list=[]
current_url=""
course=[]
delcourses=[]
res1=[]
res=[]
flags=None
flag=True
current_campus=None
campus_list=[]
PUB_PEM = b""
FP_VISITOR_ID = None                 # 新增：全局指纹ID
FP_EVENT = threading.Event()
fpVisitorId = None 

options = Options()
options.add_argument("--headless=new")  # 无头模式
options.add_argument("--window-size=1920,1080")  # 设置窗口大小
options.add_argument('--proxy-server="direct://"')
options.add_argument('--proxy-bypass-list=*')
options.add_argument("--inprivate")  # 强制隐私模式

headers = {    "User-Agent":"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0"
           }



#登录ui
class Ui_Form(object):
    def setupUi(self, Form):
        Form.setObjectName("Form")
        Form.resize(400, 260)
        Form.setStyleSheet("""
            QWidget {
                background: #f5f7fa;
            }
            QLabel {
                font-family: '微软雅黑';
                font-size: 20px;
            }
            QLineEdit {
                border: 1px solid #bfcbd9;
                border-radius: 8px;
                padding: 6px 10px;
                font-size: 18px;
                background: #fff;
            }
            QPushButton {
                background-color: #409eff;
                color: white;
                border-radius: 8px;
                font-size: 20px;
                padding: 8px 0;
            }
            QPushButton:hover {
                background-color: #66b1ff;
            }
        """)
        self.verticalLayout = QtWidgets.QVBoxLayout(Form)
        self.verticalLayout.setContentsMargins(40, 30, 40, 30)
        self.verticalLayout.setSpacing(18)

        self.title = QtWidgets.QLabel(Form)
        self.title.setText("西安交通大学统一身份认证")
        self.title.setAlignment(QtCore.Qt.AlignCenter)
        font = QtGui.QFont()
        font.setFamily("微软雅黑")
        font.setPointSize(18)
        font.setBold(True)
        self.title.setFont(font)
        self.verticalLayout.addWidget(self.title)

        self.account = QtWidgets.QLineEdit(Form)
        self.account.setPlaceholderText("请输入账号")
        self.verticalLayout.addWidget(self.account)

        self.password = QtWidgets.QLineEdit(Form)
        self.password.setPlaceholderText("请输入密码")
        self.password.setEchoMode(QtWidgets.QLineEdit.Password)
        self.verticalLayout.addWidget(self.password)

        self.pushButton = QtWidgets.QPushButton(Form)
        self.pushButton.setText("登录")
        self.verticalLayout.addWidget(self.pushButton)

#轮次ui
class Ui_Form1(object):
    def setupUi(self, Form):
        Form.setObjectName("Form")
        Form.resize(381, 232)
        Form.setStyleSheet("""
            QWidget {
                background: #f5f7fa;
            }
            QLabel {
                font-family: '微软雅黑';
                font-size: 20px;
            }
            QComboBox {
                border: 1px solid #bfcbd9;
                border-radius: 8px;
                padding: 6px 10px;
                font-size: 18px;
                background: #fff;
            }
            QPushButton {
                background-color: #409eff;
                color: white;
                border-radius: 8px;
                font-size: 20px;
                padding: 8px 0;
            }
            QPushButton:hover {
                background-color: #66b1ff;
            }
        """)
        self.verticalLayout = QtWidgets.QVBoxLayout(Form)
        self.verticalLayout.setContentsMargins(40, 30, 40, 30)
        self.verticalLayout.setSpacing(18)

        self.title = QtWidgets.QLabel(Form)
        self.title.setText("选择轮次")
        self.title.setAlignment(QtCore.Qt.AlignCenter)
        font = QtGui.QFont()
        font.setFamily("微软雅黑")
        font.setPointSize(18)
        font.setBold(True)
        self.title.setFont(font)
        self.verticalLayout.addWidget(self.title)

        self.comboBox = QtWidgets.QComboBox(Form)
        self.comboBox.setObjectName("comboBox")
        self.verticalLayout.addWidget(self.comboBox)

        self.pushButton = QtWidgets.QPushButton(Form)
        self.pushButton.setObjectName("pushButton")
        self.pushButton.setText("确定")
        self.verticalLayout.addWidget(self.pushButton)

        QtCore.QMetaObject.connectSlotsByName(Form)


#main窗口ui
class Ui_MainWindow(object):
    def setupUi(self, MainWindow):
        MainWindow.setObjectName("MainWindow")
        MainWindow.resize(752, 391)
        self.centralwidget = QtWidgets.QWidget(MainWindow)
        self.centralwidget.setObjectName("centralwidget")
        self.verticalLayout_3 = QtWidgets.QVBoxLayout(self.centralwidget)
        self.verticalLayout_3.setObjectName("verticalLayout_3")
        self.centralwidget.setStyleSheet("""
            QWidget {
                background: #f5f7fa;
            }
            QLabel {
                font-family: '微软雅黑';
                font-size: 20px;
            }
            QLineEdit {
                border: 1px solid #bfcbd9;
                border-radius: 8px;
                padding: 6px 10px;
                font-size: 18px;
                background: #fff;
            }
            QComboBox {
                border: 1px solid #bfcbd9;
                border-radius: 8px;
                padding: 6px 10px;
                font-size: 18px;
                background: #fff;
            }
            QPushButton {
                background-color: #409eff;
                color: white;
                border-radius: 8px;
                font-size: 20px;
                padding: 10px 0;
            }
            QPushButton:hover {
                background-color: #66b1ff;
            }
            QTableWidget {
                font-size: 18px;
                background-color: #fff;
                border-radius: 8px;
                gridline-color: #dcdfe6;
            }
            QToolBar {
                background: #ffffff;
                border-bottom: 1px solid #dcdfe6;
                padding: 10px 20px;
            }
            QToolButton {
                background: #409eff;
                color: white;
                border-radius: 8px;
                font-size: 18px;
                padding: 6px 12px;
                margin-right: 8px;
            }
            QToolButton:hover {
                background: #66b1ff;
            }
            QHeaderView::section {
                background-color: #ffffff;
                font-size: 18px;
                font-family: '微软雅黑';
                font-weight: bold;
                border-bottom: 2px solid #409eff;  /* 表头和内容之间的横线 */
                padding: 6px;
            }
        """)
        self.widget_2 = QtWidgets.QWidget(self.centralwidget)
        self.widget_2.setObjectName("widget_2")
        self.verticalLayout_2 = QtWidgets.QVBoxLayout(self.widget_2)
        self.verticalLayout_2.setObjectName("verticalLayout_2")
        self.widget_3 = QtWidgets.QWidget(self.widget_2)
        self.widget_3.setObjectName("widget_3")
        self.horizontalLayout_3 = QtWidgets.QHBoxLayout(self.widget_3)
        self.horizontalLayout_3.setObjectName("horizontalLayout_3")
        self.label = QtWidgets.QLabel(self.widget_3)
        self.label.setObjectName("label")
        self.horizontalLayout_3.addWidget(self.label)
        self.comboBox = QtWidgets.QComboBox(self.widget_3)
        sizePolicy = QtWidgets.QSizePolicy(QtWidgets.QSizePolicy.Expanding, QtWidgets.QSizePolicy.Fixed)
        sizePolicy.setHorizontalStretch(0)
        sizePolicy.setVerticalStretch(0)
        sizePolicy.setHeightForWidth(self.comboBox.sizePolicy().hasHeightForWidth())
        self.comboBox.setSizePolicy(sizePolicy)
        self.comboBox.setObjectName("comboBox")
        self.horizontalLayout_3.addWidget(self.comboBox)
        self.pushButton_4 = QtWidgets.QPushButton(self.widget_3)
        self.pushButton_4.setObjectName("pushButton_4")
        self.horizontalLayout_3.addWidget(self.pushButton_4)
        self.verticalLayout_2.addWidget(self.widget_3)
        self.widget_4 = QtWidgets.QWidget(self.widget_2)
        self.widget_4.setObjectName("widget_4")
        self.verticalLayout = QtWidgets.QVBoxLayout(self.widget_4)
        self.verticalLayout.setObjectName("verticalLayout")
        self.widget_5 = QtWidgets.QWidget(self.widget_4)
        self.widget_5.setObjectName("widget_5")
        self.horizontalLayout_2 = QtWidgets.QHBoxLayout(self.widget_5)
        self.horizontalLayout_2.setObjectName("horizontalLayout_2")
        self.label_2 = QtWidgets.QLabel(self.widget_5)
        self.label_2.setObjectName("label_2")
        self.horizontalLayout_2.addWidget(self.label_2)
        self.lineEdit_2 = QtWidgets.QLineEdit(self.widget_5)
        self.lineEdit_2.setObjectName("lineEdit_2")
        self.horizontalLayout_2.addWidget(self.lineEdit_2)
        self.verticalLayout.addWidget(self.widget_5)
        self.widget_6 = QtWidgets.QWidget(self.widget_4)
        self.widget_6.setObjectName("widget_6")
        self.horizontalLayout_4 = QtWidgets.QHBoxLayout(self.widget_6)
        self.horizontalLayout_4.setObjectName("horizontalLayout_4")
        self.label_3 = QtWidgets.QLabel(self.widget_6)
        self.label_3.setObjectName("label_3")
        self.horizontalLayout_4.addWidget(self.label_3)
        self.comboBox_2 = QtWidgets.QComboBox(self.widget_6)
        self.comboBox_2.setObjectName("comboBox_2")
        self.horizontalLayout_4.addWidget(self.comboBox_2)
        self.verticalLayout.addWidget(self.widget_6)
        self.widget_7 = QtWidgets.QWidget(self.widget_4)
        self.widget_7.setObjectName("widget_7")
        self.horizontalLayout_5 = QtWidgets.QHBoxLayout(self.widget_7)
        self.horizontalLayout_5.setObjectName("horizontalLayout_5")
        self.pushButton_3 = QtWidgets.QPushButton(self.widget_7)
        self.pushButton_3.setObjectName("pushButton_3")
        self.horizontalLayout_5.addWidget(self.pushButton_3)
        self.pushButton_5 = QtWidgets.QPushButton(self.widget_7)
        self.pushButton_5.setObjectName("pushButton_5")
        self.horizontalLayout_5.addWidget(self.pushButton_5)
        self.verticalLayout.addWidget(self.widget_7)
        self.verticalLayout_2.addWidget(self.widget_4)
        self.verticalLayout_3.addWidget(self.widget_2)
        self.widget = QtWidgets.QWidget(self.centralwidget)
        self.widget.setObjectName("widget")
        self.horizontalLayout = QtWidgets.QHBoxLayout(self.widget)
        self.horizontalLayout.setObjectName("horizontalLayout")
        self.lineEdit = QtWidgets.QLineEdit(self.widget)
        self.lineEdit.setObjectName("lineEdit")
        self.horizontalLayout.addWidget(self.lineEdit)
        self.pushButton = QtWidgets.QPushButton(self.widget)
        self.pushButton.setObjectName("pushButton")
        self.horizontalLayout.addWidget(self.pushButton)
        self.pushButton_2 = QtWidgets.QPushButton(self.widget)
        self.pushButton_2.setObjectName("pushButton_2")
        self.horizontalLayout.addWidget(self.pushButton_2)
        self.verticalLayout_3.addWidget(self.widget)
        self.pushButton_6 = QtWidgets.QPushButton(self.centralwidget)
        self.pushButton_6.setObjectName("pushButton_6")
        self.verticalLayout_3.addWidget(self.pushButton_6)
        self.tableWidget = QtWidgets.QTableWidget(self.centralwidget)
        self.tableWidget.setEditTriggers(QtWidgets.QAbstractItemView.NoEditTriggers)
        self.tableWidget.setObjectName("tableWidget")
        self.tableWidget.setColumnCount(0)
        self.tableWidget.setRowCount(0)
        self.tableWidget.horizontalHeader().setStretchLastSection(True)
        self.verticalLayout_3.addWidget(self.tableWidget)
        MainWindow.setCentralWidget(self.centralwidget)
        self.toolBar = QtWidgets.QToolBar(MainWindow)
        self.toolBar.setObjectName("toolBar")
        MainWindow.addToolBar(QtCore.Qt.TopToolBarArea, self.toolBar)
        self.toolBar_2 = QtWidgets.QToolBar(MainWindow)
        self.toolBar_2.setObjectName("toolBar_2")
        MainWindow.addToolBar(QtCore.Qt.TopToolBarArea, self.toolBar_2)
        self.toolBar_3 = QtWidgets.QToolBar(MainWindow)
        self.toolBar_3.setObjectName("toolBar_3")
        MainWindow.addToolBar(QtCore.Qt.TopToolBarArea, self.toolBar_3)
        self.toolBar_4 = QtWidgets.QToolBar(MainWindow)
        self.toolBar_4.setObjectName("toolBar_4")
        MainWindow.addToolBar(QtCore.Qt.TopToolBarArea, self.toolBar_4)
        self.toolBar_5 = QtWidgets.QToolBar(MainWindow)
        self.toolBar_5.setObjectName("toolBar_5")
        MainWindow.addToolBar(QtCore.Qt.TopToolBarArea, self.toolBar_5)
        self.toolBar_6 = QtWidgets.QToolBar(MainWindow)
        self.toolBar_6.setObjectName("toolBar_6")
        MainWindow.addToolBar(QtCore.Qt.TopToolBarArea, self.toolBar_6)
        self.toolBar_7 = QtWidgets.QToolBar(MainWindow)
        self.toolBar_7.setObjectName("toolBar_7")
        MainWindow.addToolBar(QtCore.Qt.TopToolBarArea, self.toolBar_7)
        self.toolBar_8 = QtWidgets.QToolBar(MainWindow)
        self.toolBar_8.setObjectName("toolBar_8")
        MainWindow.addToolBar(QtCore.Qt.TopToolBarArea, self.toolBar_8)
        self.action = QtWidgets.QAction(MainWindow)
        self.action.setObjectName("action")
        self.action_2 = QtWidgets.QAction(MainWindow)
        self.action_2.setObjectName("action_2")
        self.action_3 = QtWidgets.QAction(MainWindow)
        self.action_3.setObjectName("action_3")
        self.action_4 = QtWidgets.QAction(MainWindow)
        self.action_4.setObjectName("action_4")
        self.action_5 = QtWidgets.QAction(MainWindow)
        self.action_5.setObjectName("action_5")
        self.action_6 = QtWidgets.QAction(MainWindow)
        self.action_6.setObjectName("action_6")
        self.action_7 = QtWidgets.QAction(MainWindow)
        self.action_7.setObjectName("action_7")
        self.action_8 = QtWidgets.QAction(MainWindow)
        self.action_8.setObjectName("action_8")
        self.toolBar.addAction(self.action)
        self.toolBar_2.addAction(self.action_2)
        self.toolBar_3.addAction(self.action_3)
        self.toolBar_4.addAction(self.action_4)
        self.toolBar_5.addAction(self.action_5)
        self.toolBar_6.addAction(self.action_6)
        self.toolBar_7.addAction(self.action_7)
        self.toolBar_8.addAction(self.action_8)
        self.tableWidget.setColumnCount(4)
        self.tableWidget.setRowCount(10)
        self.tableWidget.setHorizontalHeaderLabels(["课程班编号","课程名称","上课教师","上课时间及地点"])
        # 设置所有label字体
        font = QtGui.QFont()
        font.setFamily("微软雅黑")
        font.setPointSize(20)
        font.setBold(True)
        self.label.setFont(font)
        self.label_2.setFont(font)
        self.label_3.setFont(font)

        # 设置所有按钮字体
        btn_font = QtGui.QFont()
        btn_font.setFamily("微软雅黑")
        btn_font.setPointSize(20)
        for btn in [self.pushButton, self.pushButton_2, self.pushButton_3, self.pushButton_4, self.pushButton_5, self.pushButton_6]:
            btn.setFont(btn_font)

        # 设置所有输入框和下拉框字体
        edit_font = QtGui.QFont()
        edit_font.setFamily("微软雅黑")
        edit_font.setPointSize(18)
        self.lineEdit.setFont(edit_font)
        self.lineEdit_2.setFont(edit_font)
        self.comboBox.setFont(edit_font)
        self.comboBox_2.setFont(edit_font)

        # 设置表格字体
        table_font = QtGui.QFont()
        table_font.setFamily("微软雅黑")
        table_font.setPointSize(18)
        self.tableWidget.setFont(table_font)
        self.widget.hide()
        self.widget_2.hide()
        self.tableWidget.hide()
        self.pushButton_6.hide()
        self.tableWidget.horizontalHeader().setStretchLastSection(True)
        self.tableWidget.resizeColumnToContents(0)
        self.retranslateUi(MainWindow)
        QtCore.QMetaObject.connectSlotsByName(MainWindow)

    def retranslateUi(self, MainWindow):
        _translate = QtCore.QCoreApplication.translate
        MainWindow.setWindowTitle(_translate("MainWindow", "XJTU选课助手"))
        self.label.setText(_translate("MainWindow", "选择课程"))
        self.pushButton_4.setText(_translate("MainWindow", "删除"))
        self.label_2.setText(_translate("MainWindow", "添加冲突课程（课程班号）"))
        self.label_3.setText(_translate("MainWindow", "删除冲突课程（课程班号）"))
        self.pushButton_3.setText(_translate("MainWindow", "添加"))
        self.pushButton_5.setText(_translate("MainWindow", "删除"))
        self.pushButton.setText(_translate("MainWindow", "搜索"))
        self.pushButton_2.setText(_translate("MainWindow", "保存"))
        self.pushButton_6.setText(_translate("MainWindow", "开始"))
        self.toolBar.setWindowTitle(_translate("MainWindow", "toolBar"))
        self.toolBar_2.setWindowTitle(_translate("MainWindow", "toolBar_2"))
        self.toolBar_3.setWindowTitle(_translate("MainWindow", "toolBar_3"))
        self.toolBar_4.setWindowTitle(_translate("MainWindow", "toolBar_4"))
        self.toolBar_5.setWindowTitle(_translate("MainWindow", "toolBar_5"))
        self.toolBar_6.setWindowTitle(_translate("MainWindow", "toolBar_6"))
        self.toolBar_7.setWindowTitle(_translate("MainWindow", "toolBar_7"))
        self.toolBar_8.setWindowTitle(_translate("MainWindow", "toolBar_8"))
        self.action.setText(_translate("MainWindow", "已选课程"))
        self.action_2.setText(_translate("MainWindow", "主修推荐课程"))
        self.action_3.setText(_translate("MainWindow", "方案内跨年级课程"))
        self.action_4.setText(_translate("MainWindow", "方案外课程"))
        self.action_5.setText(_translate("MainWindow", "基础通识类"))
        self.action_6.setText(_translate("MainWindow", "主修课程（体育）"))
        self.action_7.setText(_translate("MainWindow", "开始选课"))
        self.action_8.setText(_translate("MainWindow", "配置"))

class mainw(QMainWindow):
    def __init__(self,):
        super().__init__()
    def che(self):
        self.couresche=courseResult()
        self.couresche.start()
    def starts(self):
        self.startss=startss()

class courseResult(QThread):
    def __init__(self) :
        super().__init__()
        self.stoprun=False
    def run(self):
        global res1, headers, number, xklcdm
        self.stoprun=False
        res1=[]
        url="https://xkfw.xjtu.edu.cn/xsxkapp/sys/xsxkapp/elective/courseResult.do"
        param={
            "timestamp":str(see()),
            "studentCode": str(number),
            "electiveBatchCode": str(xklcdm),
        }
        try:
            resp=session.get(url=url,params=param,headers=headers)
            t=int(resp.json()["totalCount"])
            d=resp.json()["dataList"]
        except:
            d=[]
            t=0
        if(d==None):
            d=[]
            t=0
        for i in range(t):
            cour=[]
            cour.append(d[i]["teachingClassID"])
            cour.append(d[i]["courseName"])
            cour.append(d[i]["teacherName"])
            cour.append(d[i]["teachingPlace"])
            res1.append(cour)
        self.stoprun=True        
 
class startss(QThread):
    que=pyqtSignal()
    bu=pyqtSignal()
    def __init__(self) :
        super().__init__()
        self.mutex=QMutex()
        self.condition=QWaitCondition()
        self.is_paused=False
    def run(self):
        global flags
        global res1
        global course
        global flag
        flags=[0]*len(course)
        while True:
            #not flag
            login3_sync_qthread()
            self.que.emit()
            self.pause()
            self.check_mutex()
            for i in range(4000):
                sleep(0.1)
                flag1=True
                for j in range(len(course)):
                    if flags[j]==0:
                        flag1=False
                        if capacity(course[j][0]):
                            for k in delcourses[j]:
                                deleteVolunteer(k)
                            volunteer(course[j][0],course[j][4],course[j][5])
                if flag1:
                    flag=True
                    self.bu.emit()                
            sleep(0.1)
        
    def pause(self):
        self.mutex.lock()
        self.is_paused=True
        self.mutex.unlock()
    def resume(self):
        self.mutex.lock()
        self.is_paused=False
        self.condition.wakeAll()
        self.mutex.unlock()
    def check_mutex(self):
        self.mutex.lock()
        while self.is_paused:
            self.condition.wait(self.mutex)
        self.mutex.unlock()
        
class LoginThread(QThread):
    login_result = QtCore.pyqtSignal(str)  # 登录结果信号
    def run(self):
        msg = login()
        self.login_result.emit(msg)
        
class Login3Thread(QThread):
    finished = pyqtSignal(object)  # 登录完成信号，传递结果

    def run(self):
        result = login3()
        self.finished.emit(result)        


def see():
    cu_t = datetime.now()
    se = cu_t.timestamp()*1000
    se = int(se)
    return se

def capacity(teachingClassId):
    global number
    global headers
    url="https://xkfw.xjtu.edu.cn/xsxkapp/sys/xsxkapp/elective/teachingclass/capacity.do"
    param={
        "teachingClassId":str(teachingClassId),
        "capacitySuffix":"",
        "xh":str(number),
        "timestamp": str(see())
    }
    fl=True
    while fl:
        try:
            resp=session.get(url=url,params=param,headers=headers)
            #print(int(resp.json()["data"]["numberOfSelected"]))
            flag =(int(resp.json()["data"]["numberOfSelected"])<int(resp.json()["data"]["classCapacity"]))
            fl=False
        except:
            fl=True
    return flag

def deleteVolunteer(teachingClassId):
    global number
    global xklcdm
    global headers
    txkc={"data":{"operationType":"2","studentCode":str(number),"electiveBatchCode":str(xklcdm),"teachingClassId":teachingClassId,"isMajor":"1"}}
    param={
        "timestamp": str(see()),
        "deleteParam": str(txkc)
    }
    url="https://xkfw.xjtu.edu.cn/xsxkapp/sys/xsxkapp/elective/deleteVolunteer.do"
    try:
        resp=session.get(url=url,params=param,headers=headers)
        fl=False
    except:
        fl=True

def volunteer(teachingClassId,teachingClassType,campus):
    global headers, number, xklcdm
    xk={"data":{"operationType":"1","studentCode":str(number),"electiveBatchCode":str(xklcdm),"teachingClassId":teachingClassId,"isMajor":"1","campus":str(campus),"teachingClassType":teachingClassType}}
    url="https://xkfw.xjtu.edu.cn/xsxkapp/sys/xsxkapp/elective/volunteer.do"
    param={
        "addParam": str(xk)
    }
    fl=True
    try:
        resp=session.post(url=url,data=param,headers=headers)
        fl=False
    except:
        fl=True


def getfpVisitorId():
    global service
    driver = webdriver.Edge(service=service, options=options)
    driver.get("about:blank")

    # 1) 以 <script> 标签注入本地 IIFE 内容（保证是全局作用域）
    # 获取PyInstaller打包后的资源路径

    src = Path(resource_path("iife.min.js")).read_text(encoding="utf-8")
    driver.execute_script("""
    var s = document.createElement('script');
    s.type = 'text/javascript';
    s.text = arguments[0];
    document.head.appendChild(s);
    """, src)

    # 2) 等待库加载完成
    driver.execute_async_script("""
    const done = arguments[0];
    (function wait(){ if (window.FingerprintJS) done(true); else setTimeout(wait, 10); })();
    """)

    # 3) 获取指纹
    result = driver.execute_async_script("""
    const done = arguments[0];
    FingerprintJS.load().then(fp => fp.get())
      .then(r => done(r.visitorId))  // 只返回短 ID
      .catch(e => done({ error: (e && e.message) || String(e) }));
    """)
    driver.quit()
    return result

def _fp_worker():
    global FP_VISITOR_ID
    try:
        FP_VISITOR_ID = getfpVisitorId()
    except Exception:
        FP_VISITOR_ID = None
    finally:
        FP_EVENT.set()

def start_fp_preloader():
    FP_EVENT.clear()
    threading.Thread(target=_fp_worker, name="fp_preloader", daemon=True).start()
# ...existing code...


def encrypt_jsencrypt(plaintext: str) -> str:
    pub = serialization.load_pem_public_key(PUB_PEM)
    ct = pub.encrypt(plaintext.encode("utf-8"), padding.PKCS1v15())
    return "__RSA__" + base64.b64encode(ct).decode()


def login():
    global service, options, browser, number, headers,current_url,token
    global account, pwd, FP_VISITOR_ID, fpVisitorId
    global PUB_PEM
    url1 = 'https://xkfw.xjtu.edu.cn'
    resp1 = session.get(url1, headers=headers)
    resp1.encoding = resp1.apparent_encoding  # 便于解析

    # 解析 execution（XPath）
    tree = html.fromstring(resp1.text)

    # 1) 你的 XPath：//*[@id="fm1"]/input[8]/@value
    vals = tree.xpath('//*[@id="fm1"]/input[8]/@value')
    #resp1的url和数据写入
    url3 = resp1.url
    execution = vals[0]
    url2 = 'https://login.xjtu.edu.cn/cas/jwt/publicKey'
    resp2 = session.get(url2, headers=headers)
    # print(resp2.text)
    pem_text = resp2.text.strip()
    PUB_PEM = pem_text.encode('utf-8')
    fpVisitorId = (FP_EVENT.wait(10) and FP_VISITOR_ID) or (lambda: (lambda v: v if v else "")(getfpVisitorId()))()
    data = {
        "username" : str(account),
        "password" : encrypt_jsencrypt(str(pwd)),
        "captcha"  : "",
        "currentMenu" : "1",
        "failN" : "0",
        "mfaState" : "",
        "execution" : execution,
        "_eventId" : "submit",
        "geolocation" : "",
        "fpVisitorId" : str(fpVisitorId),
        "trustAgent" : "",
        "submit1" : "Login1"
    }
    resp3 = session.post(url3, headers=headers, data=data, allow_redirects=False)
    # 401 return "登录失败"
    if resp3.status_code != 302:
        return "登录失败"
    url4 = resp3.headers["Location"]
    resp4 = session.get(url4, headers=headers, allow_redirects=False)
    url4 = resp4.headers["Location"]
    resp4 = session.get(url4, headers=headers, allow_redirects=False)
    url4 = resp4.headers["Location"]
    resp4 = session.get(url4, headers=headers, allow_redirects=False)
    url4 = resp4.headers["Location"]
    number = url4.split("employeeNo=")[1].split("&")[0]
    session.get(url4, headers=headers, allow_redirects=True)
    
    
    url="https://xkfw.xjtu.edu.cn/xsxkapp/sys/xsxkapp/student/register.do?number="+str(number)
    resp=session.get(url=url,headers=headers)
    token=resp.json()['data']['token']
    headers['Token']=token
    
    return resp.json()["msg"]


    
def qdlc():
    global xklcdm, list
    i=list[form1.comboBox.currentIndex()]
    xklcdm=i['code']
    if i['canSelect']=="0":
        QtWidgets.QMessageBox.warning(window1, "警告", "请选择可选轮次！")
        return
    jrlc()
    window1.close()
    mainwin.show()
    queXQ()
    yxkc()

def queXQ():
    global headers, campus_list
    url="https://xkfw.xjtu.edu.cn/xsxkapp/sys/xsxkapp/publicinfo/dictionary.do?timestamp="+str(see())
    resp=session.get(url=url,headers=headers)
    campus_list=resp.json()["data"]["dictionaryList"]["XQ"]


def jrlc():
    global headers, number, xklcdm, current_campus
    url="https://xkfw.xjtu.edu.cn/xsxkapp/sys/xsxkapp/student/xkxf.do"
    param={
        "xh": str(number),
        "xklcdm": str(xklcdm),
        "xklclx": "01"
    }
    resp=session.post(url=url,data=param,headers=headers)
    current_campus = resp.json()["data"]["campus"]
def xklc():
    global  headers, number, list, current_url
    window.close()
    #去掉window原有ui，载入新ui
    
    form1.setupUi(window1)
    url="https://xkfw.xjtu.edu.cn/xsxkapp/sys/xsxkapp/student/"+str(number)+".do?timestamp="+str(see())
    resp=session.get(url=url,headers=headers)
    list=resp.json()['data']['electiveBatchList']
    for i in list:
        form1.comboBox.addItem(i['name'])
    form1.pushButton.clicked.connect(qdlc)
    window1.show()  #显示选课轮次




login_thread = None


def login_botton_clicked():
    global account, pwd, login_thread
    form.pushButton.setEnabled(False)
    account = form.account.text().strip()  # 获取账号输入框的内容
    pwd = form.password.text().strip()  # 获取密码输入框的内容
    if not account or not pwd:
        QtWidgets.QMessageBox.warning(window, "警告", "账号或密码不能为空！")
        return
    login_thread = LoginThread()
    login_thread.login_result.connect(on_login_result)
    login_thread.start()
        
def on_login_result(msg):
    QtWidgets.QMessageBox.information(window, "提示", msg + "！")
    form.pushButton.setEnabled(True)
    if "成功" in msg:
        xklc()
        form.pushButton.setEnabled(False)  # 登录成功后禁用登录按钮





def savee():
    global course, res, current_campus, form2
    for i in range(len(res)):
        if (form2.tableWidget.cellWidget(i,4).checkbox.isChecked()):
            temp=res[i]
            temp.append(current_campus)
            course.append(temp)
            delcourses.append([])
    course=[element for index , element in enumerate(course) if element not in course[:index]]

def readconfig():
    global course
    global delcourses
    f=open('config.ini','r',encoding='utf-8')
    con=f.read()
    f.close()
    try:
        conf=eval(con)
        course=conf["course"]
        delcourses=conf["delcourses"]
    except:
        return

def saveconfig():
    global course
    global delcourses    
    config=dict(course=course,delcourses=delcourses)
    with open('./config.ini','w',encoding='utf-8') as fp:
        fp.write(str(config))

def campus_changed():
    global current_campus, campus_list
    current_campus=campus_list[form2.comboBox_2.currentIndex()]["code"]
    #print(current_campus)
def pz():
    global campus_list, current_campus
    form2.widget.hide()
    form2.widget_2.show()
    form2.widget_6.show()
    form2.tableWidget.hide()
    form2.pushButton_6.hide()
    form2.widget_3.hide()
    form2.widget_5.hide()
    form2.comboBox_2.clear()
    form2.label_3.setText("校区")
    if form2.pushButton_3.receivers(form2.pushButton_3.clicked)>0:
        form2.pushButton_3.clicked.disconnect()
    form2.pushButton_3.clicked.connect(saveconfig)
    if form2.pushButton_5.receivers(form2.pushButton_5.clicked)>0:
        form2.pushButton_5.clicked.disconnect()
    form2.pushButton_5.clicked.connect(readconfig)
    if form2.comboBox_2.receivers(form2.comboBox_2.currentIndexChanged)>0:
        form2.comboBox_2.currentIndexChanged.disconnect()
    
    form2.pushButton_3.setText("保存")
    form2.pushButton_5.setText("读取")
    for i in campus_list:
        form2.comboBox_2.addItem(i["name"])
    if current_campus !=None:
        for i in campus_list:
            if i["code"]==current_campus:
                form2.comboBox_2.setCurrentIndex(campus_list.index(i))
                break
    form2.comboBox_2.currentIndexChanged.connect(campus_changed)

def quee():
    global course
    mainwin.startss.pause()
    mainwin.che()
    while not mainwin.couresche.stoprun:
        sleep(0.05)
    cour=[]
    form2.tableWidget.clearContents()
    form2.tableWidget.setColumnCount(5)
    form2.tableWidget.setRowCount(len(course))
    form2.tableWidget.setHorizontalHeaderLabels(["课程班编号","课程名称","上课教师","上课时间及地点","结果"])
    for i in res1:
        cour.append(i[0])
    for j in range(len(course)):
        form2.tableWidget.setItem(j,0,QTableWidgetItem(course[j][0]))
        form2.tableWidget.setItem(j,1,QTableWidgetItem(course[j][1]))
        form2.tableWidget.setItem(j,2,QTableWidgetItem(course[j][2]))
        form2.tableWidget.setItem(j,3,QTableWidgetItem(course[j][3]))
        if course[j][0] in cour:
            flags[j]=1
            form2.tableWidget.setItem(j,4,QTableWidgetItem("✓"))
        else:
            flags[j]=0
            form2.tableWidget.setItem(j,4,QTableWidgetItem("×"))
    mainwin.startss.resume()
def butt():
    form2.pushButton_6.setText("开始")
    mainwin.startss.terminate()
    login3_sync_qthread()
    quee()

def yxkc():
    global res1
    if form2.comboBox_2.receivers(form2.comboBox_2.currentIndexChanged)>0:
        form2.comboBox_2.currentIndexChanged.disconnect()
    form2.widget.hide()
    form2.widget_2.hide()
    form2.pushButton_6.hide()
    form2.tableWidget.show()
    form2.tableWidget.clearContents()
    form2.tableWidget.setColumnCount(4)
    form2.tableWidget.setHorizontalHeaderLabels(["课程班编号","课程名称","上课教师","上课时间及地点"])
    mainwin.che()
    yc=0
    while not mainwin.couresche.stoprun:
        sleep(0.05)
    form2.tableWidget.setRowCount(len(res1))
    for i in res1:
        for j in range(4):
            form2.tableWidget.setItem(yc,j,QTableWidgetItem(i[j]))
        yc=yc+1

def tjkc():
    if form2.comboBox_2.receivers(form2.comboBox_2.currentIndexChanged)>0:
        form2.comboBox_2.currentIndexChanged.disconnect()
    form2.widget.show()
    form2.widget_2.hide()
    form2.tableWidget.show()
    form2.pushButton_6.hide()
    form2.tableWidget.clearContents()
    if form2.pushButton.receivers(form2.pushButton.clicked)>0:
        form2.pushButton.clicked.disconnect()
    form2.pushButton.clicked.connect(quetjkc)
    quetjkc()

def quetjkc():
    global res, headers
    global number, xklcdm, current_campus
    row=0
    form2.tableWidget.clearContents()
    form2.tableWidget.setColumnCount(5)
    form2.tableWidget.setHorizontalHeaderLabels(["课程班编号","课程名称","上课教师","上课时间及地点","选择"])
    res=[]
    teachingClassType="TJKC"
    queryContent=form2.lineEdit.text()
    xk={"data":{"studentCode":str(number),"campus":str(current_campus),"electiveBatchCode":str(xklcdm),"isMajor":"1","teachingClassType":teachingClassType,"checkConflict":"2","checkCapacity":"2","queryContent":queryContent},"pageSize":"50","pageNumber":"0","order":""}
    url="https://xkfw.xjtu.edu.cn/xsxkapp/sys/xsxkapp/elective/recommendedCourse.do"
    param={
        "querySetting": str(xk)
    }
    try:
        resp=session.post(url=url,data=param,headers=headers)
        d=resp.json()["dataList"]
    except:
        d=[]
    if(d==None):
        d=[]
    for a in d:
        try:
            t=int(a["number"])
        except:
            t=0
        for j in range(t):#a["tcList"]:
            cour=[]
            cour.append(a["tcList"][j]["teachingClassID"])
            cour.append(a["courseName"])
            cour.append(a["tcList"][j]["teacherName"])
            cour.append(a["tcList"][j]["teachingPlace"])
            cour.append("TJKC")
            res.append(cour)
    try:
        count=float(resp.json()["totalCount"])
    except:
        count=0
    page=count/50
    page=ceil(page)
    for i in range(page-1):
        teachingClassType="TJKC"
        queryContent=form2.lineEdit.text()
        xk={"data":{"studentCode":str(number),"campus":str(current_campus),"electiveBatchCode":str(xklcdm),"isMajor":"1","teachingClassType":teachingClassType,"checkConflict":"2","checkCapacity":"2","queryContent":queryContent},"pageSize":"50","pageNumber":str(i+1),"order":""}
        url="https://xkfw.xjtu.edu.cn/xsxkapp/sys/xsxkapp/elective/recommendedCourse.do"
        param={
            "querySetting": str(xk)
        }
        try:
            resp=session.post(url=url,data=param,headers=headers)
            d=resp.json()["dataList"]
        except:
            d=[]
        if(d==None):
            d=[]
        for a in d:
            try:
                t=int(a["number"])
            except:
                t=0
            for j in range(t):
                cour=[]
                cour.append(a["tcList"][j]["teachingClassID"])
                cour.append(a["courseName"])
                cour.append(a["tcList"][j]["teacherName"])
                cour.append(a["tcList"][j]["teachingPlace"])
                cour.append("TJKC")
                res.append(cour)
    form2.tableWidget.setRowCount(len(res))
    for i in res:
        widget=QtWidgets.QWidget()
        widget.checkbox=QCheckBox()
        widget.checkbox.setChecked(False)
        hLayout=QtWidgets.QHBoxLayout(widget)
        hLayout.addWidget(widget.checkbox)
        hLayout.setAlignment(Qt.AlignHCenter | Qt.AlignVCenter)
        
        widget.setLayout(hLayout)
        form2.tableWidget.setCellWidget(row, 4, widget)
        for j in range(4):
            form2.tableWidget.setItem(row,j,QTableWidgetItem(i[j]))
        row=row+1

def fankc():
    if form2.comboBox_2.receivers(form2.comboBox_2.currentIndexChanged)>0:
        form2.comboBox_2.currentIndexChanged.disconnect()
    form2.widget.show()
    form2.widget_2.hide()
    form2.tableWidget.show()
    form2.pushButton_6.hide()
    form2.tableWidget.clearContents()
    if form2.pushButton.receivers(form2.pushButton.clicked)>0:
        form2.pushButton.clicked.disconnect()
    form2.pushButton.clicked.connect(quefankc)
    quefankc()

def quefankc():
    global res, headers, number, xklcdm, current_campus
    row=0
    form2.tableWidget.clearContents()
    form2.tableWidget.setColumnCount(5)
    form2.tableWidget.setHorizontalHeaderLabels(["课程班编号","课程名称","上课教师","上课时间及地点","选择"])
    res=[]
    teachingClassType="FANKC"
    queryContent=form2.lineEdit.text()
    xk={"data":{"studentCode":str(number),"campus":str(current_campus),"electiveBatchCode":str(xklcdm),"isMajor":"1","teachingClassType":teachingClassType,"checkConflict":"2","checkCapacity":"2","queryContent":queryContent},"pageSize":"50","pageNumber":"0","order":""}
    url="https://xkfw.xjtu.edu.cn/xsxkapp/sys/xsxkapp/elective/programCourse.do"
    param={
        "querySetting": str(xk)
    }
    try:
        resp=session.post(url=url,data=param,headers=headers)
        d=resp.json()["dataList"]
    except:
        d=[]
    if(d==None):
        d=[]
    for a in d:
        try:
            t=int(a["number"])
        except:
            t=0
        for j in range(t):#a["tcList"]:
            cour=[]
            cour.append(a["tcList"][j]["teachingClassID"])
            cour.append(a["courseName"])
            cour.append(a["tcList"][j]["teacherName"])
            cour.append(a["tcList"][j]["teachingPlace"])
            cour.append("FANKC")
            res.append(cour)
    try:
        count=float(resp.json()["totalCount"])
    except:
        count=0
    page=count/50
    page=ceil(page)
    for i in range(page-1):
        teachingClassType="FANKC"
        queryContent=form2.lineEdit.text()
        xk={"data":{"studentCode":str(number),"campus":str(current_campus),"electiveBatchCode":str(xklcdm),"isMajor":"1","teachingClassType":teachingClassType,"checkConflict":"2","checkCapacity":"2","queryContent":queryContent},"pageSize":"50","pageNumber":str(i+1),"order":""}
        url="https://xkfw.xjtu.edu.cn/xsxkapp/sys/xsxkapp/elective/programCourse.do"
        param={
            "querySetting": str(xk)
        }
        try:
            resp=session.post(url=url,data=param,headers=headers)
            d=resp.json()["dataList"]
        except:
            d=[]
        if(d==None):
            d=[]
        for a in d:
            try:
                t=int(a["number"])
            except:
                t=0
            for j in range(t):
                cour=[]
                cour.append(a["tcList"][j]["teachingClassID"])
                cour.append(a["courseName"])
                cour.append(a["tcList"][j]["teacherName"])
                cour.append(a["tcList"][j]["teachingPlace"])
                cour.append("FANKC")
                res.append(cour)
    form2.tableWidget.setRowCount(len(res))
    for i in res:
        widget=QtWidgets.QWidget()
        widget.checkbox=QCheckBox()
        widget.checkbox.setChecked(False)
        hLayout=QtWidgets.QHBoxLayout(widget)
        hLayout.addWidget(widget.checkbox)
        hLayout.setAlignment(Qt.AlignHCenter | Qt.AlignVCenter)
        
        widget.setLayout(hLayout)
        form2.tableWidget.setCellWidget(row, 4, widget)
        for j in range(4):
            form2.tableWidget.setItem(row,j,QTableWidgetItem(i[j]))
        row=row+1

def fawkc():
    if form2.comboBox_2.receivers(form2.comboBox_2.currentIndexChanged)>0:
        form2.comboBox_2.currentIndexChanged.disconnect()
    form2.widget.show()
    form2.widget_2.hide()
    form2.tableWidget.show()
    form2.pushButton_6.hide()
    form2.tableWidget.clearContents()
    if form2.pushButton.receivers(form2.pushButton.clicked)>0:
        form2.pushButton.clicked.disconnect()
    form2.pushButton.clicked.connect(quefawkc)
    quefawkc()

def quefawkc():
    global res, headers
    global number, xklcdm, current_campus
    row=0
    form2.tableWidget.clearContents()
    form2.tableWidget.setColumnCount(5)
    form2.tableWidget.setHorizontalHeaderLabels(["课程班编号","课程名称","上课教师","上课时间及地点","选择"])
    res=[]
    teachingClassType="FAWKC"
    queryContent=form2.lineEdit.text()
    xk={"data":{"studentCode":str(number),"campus":str(current_campus),"electiveBatchCode":str(xklcdm),"isMajor":"1","teachingClassType":teachingClassType,"checkConflict":"2","checkCapacity":"2","queryContent":queryContent},"pageSize":"50","pageNumber":"0","order":""}
    url="https://xkfw.xjtu.edu.cn/xsxkapp/sys/xsxkapp/elective/programCourse.do"
    param={
        "querySetting": str(xk)
    }
    try:
        resp=session.post(url=url,data=param,headers=headers)
        d=resp.json()["dataList"]
    except:
        d=[]
    if(d==None):
        d=[]
    for a in d:
        try:
            t=int(a["number"])
        except:
            t=0
        for j in range(t):#a["tcList"]:
            cour=[]
            cour.append(a["tcList"][j]["teachingClassID"])
            cour.append(a["courseName"])
            cour.append(a["tcList"][j]["teacherName"])
            cour.append(a["tcList"][j]["teachingPlace"])
            cour.append("FAWKC")
            res.append(cour)
    try:
        count=float(resp.json()["totalCount"])
    except:
        count=0
    page=count/50
    page=ceil(page)
    for i in range(page-1):
        teachingClassType="FAWKC"
        queryContent=form2.lineEdit.text()
        xk={"data":{"studentCode":str(number),"campus":str(current_campus),"electiveBatchCode":str(xklcdm),"isMajor":"1","teachingClassType":teachingClassType,"checkConflict":"2","checkCapacity":"2","queryContent":queryContent},"pageSize":"50","pageNumber":str(i+1),"order":""}
        url="https://xkfw.xjtu.edu.cn/xsxkapp/sys/xsxkapp/elective/programCourse.do"
        param={
            "querySetting": str(xk)
        }
        try:
            resp=session.post(url=url,data=param,headers=headers)
            d=resp.json()["dataList"]
        except:
            d=[]
        if(d==None):
            d=[]
        for a in d:
            try:
                t=int(a["number"])
            except:
                t=0
            for j in range(t):
                cour=[]
                cour.append(a["tcList"][j]["teachingClassID"])
                cour.append(a["courseName"])
                cour.append(a["tcList"][j]["teacherName"])
                cour.append(a["tcList"][j]["teachingPlace"])
                cour.append("FAWKC")
                res.append(cour)
    form2.tableWidget.setRowCount(len(res))
    for i in res:
        widget=QtWidgets.QWidget()
        widget.checkbox=QCheckBox()
        widget.checkbox.setChecked(False)
        hLayout=QtWidgets.QHBoxLayout(widget)
        hLayout.addWidget(widget.checkbox)
        hLayout.setAlignment(Qt.AlignHCenter | Qt.AlignVCenter)
        
        widget.setLayout(hLayout)
        form2.tableWidget.setCellWidget(row, 4, widget)
        for j in range(4):
            form2.tableWidget.setItem(row,j,QTableWidgetItem(i[j]))
        row=row+1

def xgxk():
    if form2.comboBox_2.receivers(form2.comboBox_2.currentIndexChanged)>0:
        form2.comboBox_2.currentIndexChanged.disconnect()
    form2.widget.show()
    form2.widget_2.hide()
    form2.tableWidget.show()
    form2.pushButton_6.hide()
    form2.tableWidget.clearContents()
    if form2.pushButton.receivers(form2.pushButton.clicked)>0:
        form2.pushButton.clicked.disconnect()
    form2.pushButton.clicked.connect(quexgxk)
    quexgxk()
    
def quexgxk():
    global res, headers
    global number, xklcdm, current_campus
    row=0
    form2.tableWidget.clearContents()
    form2.tableWidget.setColumnCount(5)
    form2.tableWidget.setHorizontalHeaderLabels(["课程班编号","课程名称","上课教师","上课时间及地点","选择"])
    res=[]
    teachingClassType="XGXK"
    queryContent=form2.lineEdit.text()
    xk={"data":{"studentCode":str(number),"campus":str(current_campus),"electiveBatchCode":str(xklcdm),"isMajor":"1","teachingClassType":teachingClassType,"checkConflict":"2","checkCapacity":"2","queryContent":queryContent},"pageSize":"50","pageNumber":"0","order":""}
    url="https://xkfw.xjtu.edu.cn/xsxkapp/sys/xsxkapp/elective/publicCourse.do"
    param={
        "querySetting": str(xk)
    }
    try:
        resp=session.post(url=url,data=param,headers=headers)
    except:
        resp={}
    try:
        d=resp.json()["dataList"]
    except:
        d=[]
    if(d==None):
        d=[]
    for a in d:
        cour=[]
        cour.append(a["teachingClassID"])
        cour.append(a["courseName"])
        cour.append(a["teacherName"])
        cour.append(a["teachingPlace"])
        cour.append("XGXK")
        res.append(cour)
    try:
        count=float(resp.json()["totalCount"])
    except:
        count=0
    page=count/50
    page=ceil(page)
    for i in range(page-1):
        teachingClassType="XGXK"
        queryContent=form2.lineEdit.text()
        xk={"data":{"studentCode":str(number),"campus":str(current_campus),"electiveBatchCode":str(xklcdm),"isMajor":"1","teachingClassType":teachingClassType,"checkConflict":"2","checkCapacity":"2","queryContent":queryContent},"pageSize":"50","pageNumber":str(i+1),"order":""}
        url="https://xkfw.xjtu.edu.cn/xsxkapp/sys/xsxkapp/elective/publicCourse.do"
        param={
            "querySetting": str(xk)
        }
        fl=True
        try:
            resp=session.post(url=url,data=param,headers=headers)
            fl=False
        except:
            fl=True
        try:
            d=resp.json()["dataList"]
        except:
            d=[]
        if(d==None):
            d=[]
        for a in d:
            cour=[]
            cour.append(a["teachingClassID"])
            cour.append(a["courseName"])
            cour.append(a["teacherName"])
            cour.append(a["teachingPlace"])
            cour.append("XGXK")
            res.append(cour)
    form2.tableWidget.setRowCount(len(res))
    for i in res:
        widget=QtWidgets.QWidget()
        widget.checkbox=QCheckBox()
        widget.checkbox.setChecked(False)
        hLayout=QtWidgets.QHBoxLayout(widget)
        hLayout.addWidget(widget.checkbox)
        hLayout.setAlignment(Qt.AlignHCenter | Qt.AlignVCenter)
        
        widget.setLayout(hLayout)
        form2.tableWidget.setCellWidget(row, 4, widget)
        for j in range(4):
            form2.tableWidget.setItem(row,j,QTableWidgetItem(i[j]))
        row=row+1

def tykc():
    if form2.comboBox_2.receivers(form2.comboBox_2.currentIndexChanged)>0:
        form2.comboBox_2.currentIndexChanged.disconnect()
    form2.widget.show()
    form2.widget_2.hide()
    form2.tableWidget.show()
    form2.pushButton_6.hide()
    form2.tableWidget.clearContents()
    if form2.pushButton.receivers(form2.pushButton.clicked)>0:
        form2.pushButton.clicked.disconnect()
    form2.pushButton.clicked.connect(quetykc)
    quetykc()
    
def quetykc():
    global res, headers
    global number, xklcdm, current_campus
    row=0
    form2.tableWidget.clearContents()
    form2.tableWidget.setColumnCount(5)
    form2.tableWidget.setHorizontalHeaderLabels(["课程班编号","课程名称","上课教师","上课时间及地点","选择"])
    res=[]
    teachingClassType="TYKC"
    queryContent=form2.lineEdit.text()
    xk={"data":{"studentCode":str(number),"campus":str(current_campus),"electiveBatchCode":str(xklcdm),"isMajor":"1","teachingClassType":teachingClassType,"checkConflict":"2","checkCapacity":"2","queryContent":queryContent},"pageSize":"50","pageNumber":"0","order":""}
    url="https://xkfw.xjtu.edu.cn/xsxkapp/sys/xsxkapp/elective/programCourse.do"
    param={
        "querySetting": str(xk)
    }
    try:
        resp=session.post(url=url,data=param,headers=headers)
        d=resp.json()["dataList"]
    except:
        d=[]
    if(d==None):
        d=[]
    for a in d:
        try:
            t=int(a["number"])
        except:
            t=0
        for j in range(t):#a["tcList"]:
            cour=[]
            cour.append(a["tcList"][j]["teachingClassID"])
            cour.append(a["courseName"]+"-"+a["tcList"][j]["sportName"])
            cour.append(a["tcList"][j]["teacherName"])
            cour.append(a["tcList"][j]["teachingPlace"])
            cour.append("TYKC")
            res.append(cour)
    try:
        count=float(resp.json()["totalCount"])
    except:
        count=0
    page=count/50
    page=ceil(page)
    for i in range(page-1):
        teachingClassType="TYKC"
        queryContent=form2.lineEdit.text()
        xk={"data":{"studentCode":str(number),"campus":str(current_campus),"electiveBatchCode":str(xklcdm),"isMajor":"1","teachingClassType":teachingClassType,"checkConflict":"2","checkCapacity":"2","queryContent":queryContent},"pageSize":"50","pageNumber":str(i+1),"order":""}
        url="https://xkfw.xjtu.edu.cn/xsxkapp/sys/xsxkapp/elective/programCourse.do"
        param={
            "querySetting": str(xk)
        }
        fl=True
        while fl:
            try:
                resp=session.post(url=url,data=param,headers=headers)
                d=resp.json()["dataList"]
                fl=False
            except:
                fl=True
        for a in d:
            try:
                t=int(a["number"])
            except:
                t=0
            for j in range(t):
                cour=[]
                cour.append(a["tcList"][j]["teachingClassID"])
                cour.append(a["courseName"]+"-"+a["tcList"][j]["sportName"])
                cour.append(a["tcList"][j]["teacherName"])
                cour.append(a["tcList"][j]["teachingPlace"])
                cour.append("TYKC")
                res.append(cour)
    form2.tableWidget.setRowCount(len(res))
    for i in res:
        widget=QtWidgets.QWidget()
        widget.checkbox=QCheckBox()
        widget.checkbox.setChecked(False)
        hLayout=QtWidgets.QHBoxLayout(widget)
        hLayout.addWidget(widget.checkbox)
        hLayout.setAlignment(Qt.AlignHCenter | Qt.AlignVCenter)
        
        widget.setLayout(hLayout)
        form2.tableWidget.setCellWidget(row, 4, widget)
        for j in range(4):
            form2.tableWidget.setItem(row,j,QTableWidgetItem(i[j]))
        row=row+1

def ksxk():
    if form2.comboBox_2.receivers(form2.comboBox_2.currentIndexChanged)>0:
        form2.comboBox_2.currentIndexChanged.disconnect()
    form2.widget.hide()
    form2.comboBox.currentIndexChanged.connect(sx)
    form2.widget_2.show()
    form2.tableWidget.show()
    form2.widget_3.show()
    form2.widget_5.show()
    form2.widget_6.show()
    form2.pushButton_6.show()
    form2.tableWidget.clearContents()
    form2.comboBox.clear()
    form2.comboBox_2.clear()
    form2.tableWidget.setColumnCount(1)
    form2.pushButton_3.setText("添加")
    form2.pushButton_5.setText("删除")
    form2.label_3.setText("删除冲突课程（课程班号）")
    form2.tableWidget.setHorizontalHeaderLabels(["课程班编号"])
    if form2.pushButton_3.receivers(form2.pushButton_3.clicked)>0:
        form2.pushButton_3.clicked.disconnect()
    form2.pushButton_3.clicked.connect(indelcourses)
    if form2.pushButton_5.receivers(form2.pushButton_5.clicked)>0:
        form2.pushButton_5.clicked.disconnect()
    form2.pushButton_5.clicked.connect(deldelcourses)
    for i in course:
        for j in range(0,4):
            if i[j]==None:
                i[j]="无"
        form2.comboBox.addItem(i[0]+"/"+i[1]+"/"+i[2]+"/"+i[3])
    sx()

def deldelcourses():
    global delcourses
    cou=delcourses[form2.comboBox.currentIndex()]
    try:
        del cou[form2.comboBox_2.currentIndex()]
    except:
        c=1
    delcourses[form2.comboBox.currentIndex()]=cou
    try:
        cou=delcourses[form2.comboBox.currentIndex()]
    except:
        cou=[]
    sx()

def indelcourses():
    global delcourses
    form2.tableWidget.clearContents()
    form2.comboBox_2.clear()
    form2.tableWidget.clearContents()
    try:
        if form2.lineEdit_2.text() != "" :
            delcourses[form2.comboBox.currentIndex()].append(form2.lineEdit_2.text())
        cou=delcourses[form2.comboBox.currentIndex()]
        cou=[element for index , element in enumerate(cou) if element not in cou[:index]]
        delcourses[form2.comboBox.currentIndex()]=cou
    except:
        cou=[]
    sx()

def sx():
    global delcourses
    form2.comboBox_2.clear()
    form2.tableWidget.clearContents()
    form2.lineEdit_2.clear()
    form2.tableWidget.setColumnCount(1)
    form2.tableWidget.setHorizontalHeaderLabels(["课程班编号"])
    try:
        cou=delcourses[form2.comboBox.currentIndex()]
    except:
        cou=[]
    for i in range(len(cou)):
        form2.tableWidget.setItem(i,0,QTableWidgetItem(cou[i]))
        form2.comboBox_2.addItem(cou[i])

def delcourse():
    try:
        del delcourses[form2.comboBox.currentIndex()]
        del course[form2.comboBox.currentIndex()]
    except:
        c=1
    form2.comboBox.clear()
    for i in course:
        for j in range(0,4):
            if i[j]==None:
                i[j]="无"
        form2.comboBox.addItem(i[0]+"/"+i[1]+"/"+i[2]+"/"+i[3])


def starts():
    global flags
    global flag
    if flag:
        mainwin.starts()
        mainwin.startss.que.connect(quee)
        mainwin.startss.bu.connect(butt)
        flag=False
        mainwin.startss.start()
        form2.pushButton_6.setText("停止")
    else:
        form2.pushButton_6.setText("开始")
        mainwin.startss.terminate()
        flag=True
        login3_sync_qthread()
        quee()


def login3():
    global account, pwd, browser, number, headers, current_url, token, xklcdm
    global service, options, browser, number, headers,current_url,token
    global account, pwd, FP_VISITOR_ID, fpVisitorId
    global PUB_PEM
    url1 = 'https://xkfw.xjtu.edu.cn'
    resp1 = session.get(url1, headers=headers)
    resp1.encoding = resp1.apparent_encoding  # 便于解析

    # 解析 execution（XPath）
    tree = html.fromstring(resp1.text)

    # 1) 你的 XPath：//*[@id="fm1"]/input[8]/@value
    vals = tree.xpath('//*[@id="fm1"]/input[8]/@value')
    #resp1的url和数据写入
    url3 = resp1.url
    execution = vals[0]
    url2 = 'https://login.xjtu.edu.cn/cas/jwt/publicKey'
    resp2 = session.get(url2, headers=headers)
    # print(resp2.text)
    pem_text = resp2.text.strip()
    PUB_PEM = pem_text.encode('utf-8')
    fpVisitorId = (FP_EVENT.wait(10) and FP_VISITOR_ID) or (lambda: (lambda v: v if v else "")(getfpVisitorId()))()
    data = {
        "username" : str(account),
        "password" : encrypt_jsencrypt(str(pwd)),
        "captcha"  : "",
        "currentMenu" : "1",
        "failN" : "0",
        "mfaState" : "",
        "execution" : execution,
        "_eventId" : "submit",
        "geolocation" : "",
        "fpVisitorId" : str(fpVisitorId),
        "trustAgent" : "",
        "submit1" : "Login1"
    }
    resp3 = session.post(url3, headers=headers, data=data, allow_redirects=False)
    url4 = resp3.headers["Location"]
    resp4 = session.get(url4, headers=headers, allow_redirects=False)
    url4 = resp4.headers["Location"]
    resp4 = session.get(url4, headers=headers, allow_redirects=False)
    url4 = resp4.headers["Location"]
    resp4 = session.get(url4, headers=headers, allow_redirects=False)
    url4 = resp4.headers["Location"]
    number = url4.split("employeeNo=")[1].split("&")[0]
    session.get(url4, headers=headers, allow_redirects=True)
    headers = {
        "User-Agent":"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0"
    }
    url="https://xkfw.xjtu.edu.cn/xsxkapp/sys/xsxkapp/student/register.do?number="+str(number)
    resp=session.get(url=url,headers=headers)
    token=resp.json()['data']['token']
    headers['Token']=token
    
    url="https://xkfw.xjtu.edu.cn/xsxkapp/sys/xsxkapp/student/xkxf.do"
    param={
        "xh": str(number),
        "xklcdm": str(xklcdm),
        "xklclx": "01"
    }
    resp=session.post(url=url,data=param,headers=headers)
    return resp

def login3_sync_qthread():
    """
    用QThread异步执行login3，并同步等待结果，不阻塞UI事件循环。
    """
    loop = QEventLoop()
    result_container = {}

    def on_finished(result):
        result_container['result'] = result
        loop.quit()

    thread = Login3Thread()
    thread.finished.connect(on_finished)
    thread.start()
    loop.exec_()  # 等待线程结束
    thread.wait()
    return result_container['result']


start_fp_preloader()
app=QApplication(sys.argv)
form=Ui_Form()
form1=Ui_Form1()
form2=Ui_MainWindow()
window=QtWidgets.QWidget()
window1=QtWidgets.QWidget()
mainwin=mainw()
form2.setupUi(mainwin)
form.setupUi(window)


icon_path = resource_path("logo.png")
icon = QtGui.QIcon(icon_path)

window.setWindowIcon(icon)
window1.setWindowIcon(icon)
mainwin.setWindowIcon(icon)
mainwin.setWindowTitle("XJTU选课助手")
window.setWindowTitle("登录")
window1.setWindowTitle("选择轮次")
flags = QtCore.Qt.Window | QtCore.Qt.CustomizeWindowHint | QtCore.Qt.WindowCloseButtonHint
window.setWindowFlags(flags)
window1.setWindowFlags(flags)
mainwin.setWindowFlags(QtCore.Qt.Window)


form.pushButton.clicked.connect(login_botton_clicked)
form2.pushButton_2.clicked.connect(savee)
form2.action.triggered.connect(yxkc)
form2.action_2.triggered.connect(tjkc)
form2.action_3.triggered.connect(fankc)
form2.action_4.triggered.connect(fawkc)
form2.action_5.triggered.connect(xgxk)
form2.action_6.triggered.connect(tykc)
form2.action_7.triggered.connect(ksxk)
form2.action_8.triggered.connect(pz)
form2.pushButton_4.clicked.connect(delcourse)
form2.pushButton_6.clicked.connect(starts)







window.show()




sys.exit(app.exec_())